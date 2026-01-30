// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/models/script_step.dart';
import 'package:club_blackout/utils/role_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/file_role_repository.dart';

class _Policy {
  final Map<String, String> preferredTargetRoleIdByActorRoleId;

  const _Policy({
    this.preferredTargetRoleIdByActorRoleId = const {},
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late RoleRepository roleRepository;

  setUpAll(() async {
    roleRepository = FileRoleRepository();
    await roleRepository.loadRoles();
  });

  GameEngine newEngine() => GameEngine(roleRepository: roleRepository);

  Role _requireRole(String id) {
    final role = roleRepository.getRoleById(id);
    if (role == null) throw StateError('Missing required roleId=$id in roles.json');
    return role;
  }

  Player _firstAliveByRoleId(GameEngine engine, String roleId) {
    return engine.players.firstWhere(
      (p) => p.isActive && p.role.id == roleId,
      orElse: () => throw StateError('No active player with roleId=$roleId'),
    );
  }

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

  void _playUntilDayScene(GameEngine engine, {required _Policy policy, int maxSteps = 1200}) {
    var safety = 0;

    bool isAtDaySceneLauncher(ScriptStep? step) {
      return engine.currentPhase == GamePhase.day &&
          step != null &&
          step.actionType == ScriptActionType.showDayScene;
    }

    while (safety < maxSteps) {
      final step = engine.currentScriptStep;

      if (isAtDaySceneLauncher(step)) {
        return;
      }

      if (step == null) {
        engine.advanceScript();
        safety++;
        continue;
      }

      switch (step.actionType) {
        case ScriptActionType.toggleOption:
          // Only Medic uses this today; default to safest option.
          engine.handleScriptOption(step, 'PROTECT');
          engine.advanceScript();
          break;

        case ScriptActionType.binaryChoice:
          // Default to "no" to avoid irreversible state changes.
          engine.handleScriptAction(step, ['no']);
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

        default:
          engine.advanceScript();
          break;
      }

      safety++;
    }

    throw StateError('Script simulation exceeded maxSteps=$maxSteps (dayCount=${engine.dayCount}, phase=${engine.currentPhase}).');
  }

  GameEngine _buildMinimalValidGameIncluding(Role roleUnderTest) {
    final engine = newEngine();

    final dealer = _requireRole('dealer');
    final partyAnimal = _requireRole('party_animal');

    engine.addPlayer('Dealer 1', role: dealer);
    engine.addPlayer('Party 1', role: partyAnimal);

    // Wallflower is required. If this is the role under test, use it in that slot.
    if (roleUnderTest.id == 'wallflower') {
      engine.addPlayer('Wallflower 1', role: roleUnderTest);
    } else {
      engine.addPlayer('Wallflower 1', role: _requireRole('wallflower'));
    }

    // Need at least one Medic and/or Bouncer. Prefer Medic unless this is under test.
    if (roleUnderTest.id == 'medic') {
      engine.addPlayer('Medic 1', role: roleUnderTest);
    } else if (roleUnderTest.id == 'bouncer') {
      engine.addPlayer('Bouncer 1', role: roleUnderTest);
    } else {
      final medic = roleRepository.getRoleById('medic');
      final bouncer = roleRepository.getRoleById('bouncer');
      if (medic != null) {
        engine.addPlayer('Medic 1', role: medic);
      } else if (bouncer != null) {
        engine.addPlayer('Bouncer 1', role: bouncer);
      }
    }

    // Ensure the role under test is present at least once.
    final alreadyPresent = engine.players.any((p) => p.role.id == roleUnderTest.id);
    if (!alreadyPresent) {
      engine.addPlayer('Test Role', role: roleUnderTest);
    }

    final validation = RoleValidator.validateGameSetup(engine.players);
    if (!validation.isValid) {
      throw StateError('Invalid minimal roster for roleId=${roleUnderTest.id}: ${validation.error}');
    }

    return engine;
  }

  test('All roles: can start and play through setup + one night', () async {
    final roles = roleRepository.roles.where((r) => r.id != 'host' && r.id != 'temp').toList();

    // Policy keeps the run stable (avoid killing the role under test by accident).
    const policy = _Policy(
      preferredTargetRoleIdByActorRoleId: {
        'dealer': 'wallflower',
        'medic': 'wallflower',
        'bouncer': 'dealer',
        'clinger': 'party_animal',
        'creep': 'party_animal',
        'roofi': 'dealer',
        'bartender': 'party_animal',
        'silver_fox': 'dealer',
      },
    );

    final failures = <String>[];

    for (final role in roles) {
      try {
        final engine = _buildMinimalValidGameIncluding(role);
        await engine.startGame();

        // Setup-night resolves when the setup script finishes and Day starts.
        _playUntilDayScene(engine, policy: policy, maxSteps: 800);
        engine.advanceScript();

        // Force a clean transition to Night 1, then resolve Night 1 to Day 2.
        if (engine.currentPhase != GamePhase.day) {
          throw StateError('Expected day phase after setup-night for roleId=${role.id}, got ${engine.currentPhase}.');
        }
        engine.skipToNextPhase();
        if (engine.currentPhase != GamePhase.night) {
          throw StateError('Expected night phase after skipping day for roleId=${role.id}, got ${engine.currentPhase}.');
        }

        _playUntilDayScene(engine, policy: policy, maxSteps: 1200);

        // Sanity: role-under-test still exists in the roster (may be dead, but should be present).
        engine.players.firstWhere((p) => p.role.id == role.id);

        // Touch a couple of known mechanics so they don't regress silently.
        if (role.id == 'second_wind') {
          final sw = _firstAliveByRoleId(engine, 'second_wind');
          if (!sw.alliance.toLowerCase().contains('party')) {
            throw StateError('Second Wind did not start on Party alliance (alliance=${sw.alliance}).');
          }
        }
      } catch (e) {
        failures.add('roleId=${role.id}: $e');
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
