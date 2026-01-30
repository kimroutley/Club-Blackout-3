    // ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/script_step.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/file_role_repository.dart';

class _Policy {
  final String medicSetupOption; // 'PROTECT' | 'REVIVE'
  final bool wallflowerWitness;
  final bool secondWindConvert;

  final Map<String, String> preferredTargetRoleIdByActorRoleId;

  /// Which role we try to vote out during the first day (if alive).
  final String dayVoteOutRoleId;

  const _Policy({
    required this.medicSetupOption,
    required this.wallflowerWitness,
    required this.secondWindConvert,
    required this.dayVoteOutRoleId,
    this.preferredTargetRoleIdByActorRoleId = const <String, String>{},
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Saved game simulation (variations)', () {
    late FileRoleRepository roleRepository;

    setUpAll(() async {
      roleRepository = FileRoleRepository();
      await roleRepository.loadRoles();
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    GameEngine _newEngine() => GameEngine(roleRepository: roleRepository);

    Player _pickTarget({
      required GameEngine engine,
      required String actorRoleId,
      required _Policy policy,
    }) {
      final preferredRoleId = policy.preferredTargetRoleIdByActorRoleId[actorRoleId];
      if (preferredRoleId != null) {
        final preferred = engine.players
            .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
            .where((p) => p.role.id == preferredRoleId)
            .cast<Player?>()
            .firstWhere((p) => p != null, orElse: () => null);
        if (preferred != null) return preferred;
      }

      return engine.players.where((p) => p.isAlive && p.isEnabled && p.role.id != 'host').first;
    }

    Future<GameEngine> _saveAndReload(
      GameEngine engine, {
      required String saveName,
    }) async {
      await engine.saveGame(saveName);
      final saves = await engine.getSavedGames();
      expect(saves, isNotEmpty);
      final saveId = saves.last.id;

      final loadedEngine = _newEngine();
      final ok = await loadedEngine.loadGame(saveId);
      expect(ok, isTrue, reason: 'Expected loadGame($saveId) to succeed.');

      // Core invariants for a playable resume.
      expect(loadedEngine.currentPhase, engine.currentPhase);
      expect(loadedEngine.dayCount, engine.dayCount);
      expect(loadedEngine.currentScriptIndex, engine.currentScriptIndex);

      // Queue must exist for the current phase.
      if (loadedEngine.currentPhase == GamePhase.day || loadedEngine.currentPhase == GamePhase.night) {
        expect(loadedEngine.scriptQueue, isNotEmpty);
      }

      // Script index should be in range or exactly at end (end-of-queue triggers phase load).
      expect(
        loadedEngine.currentScriptIndex,
        inInclusiveRange(0, loadedEngine.scriptQueue.length),
      );

      return loadedEngine;
    }

    bool _isAtDaySceneLauncher(GameEngine engine, ScriptStep? step) {
      return engine.currentPhase == GamePhase.day && step != null && step.actionType == ScriptActionType.showDayScene;
    }

    Future<GameEngine> _playScript(
      GameEngine engine, {
      required _Policy policy,
      required String savePrefix,
      int maxSteps = 1200,
      Set<String> reloadAfterStepIds = const <String>{},
    }) async {
      var safety = 0;

      while (safety < maxSteps) {
        final step = engine.currentScriptStep;

        if (_isAtDaySceneLauncher(engine, step)) {
          return engine;
        }

        if (step == null) {
          engine.advanceScript();
          safety++;
          continue;
        }

        switch (step.actionType) {
          case ScriptActionType.toggleOption:
            if (step.roleId == 'medic') {
              engine.handleScriptOption(step, policy.medicSetupOption);
            } else if (step.roleId == 'wallflower' && step.id == 'wallflower_act') {
              engine.handleScriptOption(step, policy.wallflowerWitness ? 'PEEK' : 'SKIP');
            } else {
              engine.handleScriptOption(step, 'SKIP');
            }
            engine.advanceScript();
            break;

          case ScriptActionType.binaryChoice:
            if (step.roleId == 'dealer' &&
                (step.id == 'second_wind_conversion_choice' || step.id == 'second_wind_conversion_vote')) {
              engine.handleScriptAction(step, [policy.secondWindConvert ? 'CONVERT' : 'KILL']);
            } else {
              engine.handleScriptAction(step, ['no']);
            }
            engine.advanceScript();
            break;

          case ScriptActionType.selectTwoPlayers:
            final alive = engine.players.where((p) => p.isAlive && p.isEnabled && p.role.id != 'host').toList();
            if (alive.length >= 2) {
              engine.handleScriptAction(step, [alive[0].id, alive[1].id]);
            } else if (alive.isNotEmpty) {
              engine.handleScriptAction(step, [alive[0].id, alive[0].id]);
            } else {
              engine.handleScriptAction(step, ['?']);
            }
            engine.advanceScript();
            break;

          case ScriptActionType.selectPlayer:
            final actorRoleId = step.roleId ?? 'unknown';
            final target = _pickTarget(engine: engine, actorRoleId: actorRoleId, policy: policy);
            engine.handleScriptAction(step, [target.id]);
            engine.advanceScript();
            break;

          case ScriptActionType.optional:
          case ScriptActionType.showTimer:
          case ScriptActionType.showInfo:
          case ScriptActionType.phaseTransition:
          case ScriptActionType.discussion:
          case ScriptActionType.info:
          case ScriptActionType.none:
          case ScriptActionType.showDayScene:
            engine.advanceScript();
            break;
        }

        // Periodically test persistence mid-script (this catches scriptIndex mismatches).
        if (safety == 10 || safety == 40 || (step.id.isNotEmpty && reloadAfterStepIds.contains(step.id))) {
          engine = await _saveAndReload(
            engine,
            saveName: '$savePrefix-step-$safety',
          );
        }

        // Basic script/host sanity checks.
        expect(engine.currentScriptIndex, inInclusiveRange(0, engine.scriptQueue.length));
        if (engine.currentPhase == GamePhase.day || engine.currentPhase == GamePhase.night) {
          expect(engine.scriptQueue, isNotEmpty);
        }

        safety++;
      }

      throw StateError(
        'Script simulation exceeded maxSteps=$maxSteps (dayCount=${engine.dayCount}, phase=${engine.currentPhase}).',
      );
    }

    void _voteOutRoleIfAlive(GameEngine engine, String roleId) {
      final player = engine.players.where((p) => p.isActive && p.role.id == roleId).firstOrNull;
      if (player == null) return;
      engine.voteOutPlayer(player.id);
    }

    test('full-roster: save/load resume works across key script branches', () async {
      const policies = <_Policy>[
        _Policy(
          medicSetupOption: 'PROTECT',
          wallflowerWitness: false,
          secondWindConvert: false,
          dayVoteOutRoleId: 'predator',
          preferredTargetRoleIdByActorRoleId: {
            'dealer': 'party_animal',
            'medic': 'party_animal',
            'bouncer': 'dealer',
          },
        ),
        _Policy(
          medicSetupOption: 'PROTECT',
          wallflowerWitness: true,
          secondWindConvert: true,
          dayVoteOutRoleId: 'whore',
          preferredTargetRoleIdByActorRoleId: {
            'dealer': 'wallflower',
            'medic': 'wallflower',
            'bouncer': 'dealer',
          },
        ),
        _Policy(
          medicSetupOption: 'REVIVE',
          wallflowerWitness: false,
          secondWindConvert: true,
          dayVoteOutRoleId: 'dealer',
          preferredTargetRoleIdByActorRoleId: {
            'dealer': 'party_animal',
            'medic': 'dealer',
            'bouncer': 'dealer',
          },
        ),
        _Policy(
          medicSetupOption: 'REVIVE',
          wallflowerWitness: true,
          secondWindConvert: false,
          dayVoteOutRoleId: 'drama_queen',
          preferredTargetRoleIdByActorRoleId: {
            'dealer': 'party_animal',
            'medic': 'party_animal',
            'bouncer': 'dealer',
          },
        ),
      ];

      final failures = <String>[];

      for (var i = 0; i < policies.length; i++) {
        final policy = policies[i];

        try {
          final engine0 = _newEngine();
          await engine0.createTestGame(fullRoster: true);
          await engine0.startGame();

          // Setup -> Day 1 launcher.
          var engine = await _playScript(
            engine0,
            policy: policy,
            savePrefix: 'policy-$i-setup',
            maxSteps: 1200,
          );

          // Save/load at the day-scene boundary.
          engine = await _saveAndReload(engine, saveName: 'policy-$i-day1-boundary');

          // Enter day scene.
          engine.advanceScript();
          expect(engine.currentPhase, GamePhase.day);

          // Vote out a role to trigger day-phase eventualities, then save/load.
          engine = await _saveAndReload(engine, saveName: 'policy-$i-pre-vote');
          _voteOutRoleIfAlive(engine, policy.dayVoteOutRoleId);
          engine = await _saveAndReload(engine, saveName: 'policy-$i-post-vote');

          // Move to Night 1.
          engine.skipToNextPhase();
          expect(engine.currentPhase, GamePhase.night);

          // Resolve Night 1 -> Day 2 launcher, with persistence mid-night.
          engine = await _playScript(
            engine,
            policy: policy,
            savePrefix: 'policy-$i-night1',
            maxSteps: 1600,
            reloadAfterStepIds: const {'dealer_act', 'medic_act', 'bouncer_act'},
          );

          // Morning report should exist when we land at day scene.
          expect(engine.currentPhase, GamePhase.day);
          expect(engine.lastNightSummary.trim().isNotEmpty, isTrue);

          // Enter Day 2.
          engine.advanceScript();

          // Final save/load after an entire night resolution.
          engine = await _saveAndReload(engine, saveName: 'policy-$i-after-night1');

          // Ensure the game is still in a playable state.
          expect(engine.players.where((p) => p.isActive).length, greaterThanOrEqualTo(1));
        } catch (e) {
          failures.add('policy#$i: $e');
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });
}
