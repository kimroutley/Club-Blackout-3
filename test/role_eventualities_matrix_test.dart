// ignore_for_file: no_leading_underscores_for_local_identifiers, prefer_const_constructors

import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/models/script_step.dart';
import 'package:club_blackout/utils/role_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/file_role_repository.dart';

class _ScriptPolicy {
  final String medicSetupOption; // 'PROTECT' | 'REVIVE'
  final bool wallflowerWitness;
  final bool secondWindConvert;
  final String? medicReviveTargetRoleId;

  /// Optional per-role targeting overrides.
  final Map<String, String> preferredTargetRoleIdByActorRoleId;

  const _ScriptPolicy({
    required this.medicSetupOption,
    required this.wallflowerWitness,
    required this.secondWindConvert,
    this.medicReviveTargetRoleId,
    this.preferredTargetRoleIdByActorRoleId = const {},
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RoleRepository roleRepository;

  setUpAll(() async {
    roleRepository = FileRoleRepository();
    await roleRepository.loadRoles();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  GameEngine newEngine() => GameEngine(roleRepository: roleRepository);

  Role _requireRole(String id) {
    final role = roleRepository.getRoleById(id);
    if (role == null) {
      throw StateError('Missing required role in roles.json: $id');
    }
    return role;
  }

  /// Builds a minimal valid roster that includes [roleUnderTest] (once), while
  /// satisfying RoleValidator constraints and avoiding invalid duplicates.
  GameEngine _buildMinimalValidGameIncluding(Role roleUnderTest) {
    final engine = newEngine();

    final dealer = _requireRole('dealer');
    final partyAnimal = _requireRole('party_animal');

    final includeWallflower = roleUnderTest.id != 'wallflower';
    final includeMedic = roleUnderTest.id != 'medic';
    final includeBouncer = roleUnderTest.id != 'bouncer';

    engine.addPlayer('Dealer1', role: dealer);
    engine.addPlayer('PA1', role: partyAnimal);

    if (includeWallflower) {
      engine.addPlayer('WF1', role: _requireRole('wallflower'));
    } else {
      engine.addPlayer('WF1', role: roleUnderTest);
    }

    // Need at least one Medic and/or Bouncer, but both are unique.
    if (!includeMedic) {
      // Medic is the roleUnderTest; satisfy the requirement with the Medic.
      engine.addPlayer('Medic1', role: roleUnderTest);
    } else if (!includeBouncer) {
      engine.addPlayer('Bouncer1', role: roleUnderTest);
    } else {
      // Default to Medic; if missing, fall back to Bouncer.
      final medic = roleRepository.getRoleById('medic');
      final bouncer = roleRepository.getRoleById('bouncer');
      if (medic != null) {
        engine.addPlayer('Medic1', role: medic);
      } else if (bouncer != null) {
        engine.addPlayer('Bouncer1', role: bouncer);
      }
    }

    // Ensure the role under test is present (once) if not already.
    final alreadyPresent = engine.players.any((p) => p.role.id == roleUnderTest.id);
    if (!alreadyPresent) {
      engine.addPlayer('TestRole', role: roleUnderTest);
    }

    // Ensure minimum count; startGame requires >= 4 enabled players.
    if (engine.enabledPlayers.length < 4) {
      throw StateError('Minimal roster builder produced < 4 players.');
    }

    return engine;
  }

  GameEngine _buildGameWithRoles({
    required List<String> roleIds,
  }) {
    final engine = newEngine();

    // RoleValidator requires some always-present roles; auto-inject them so
    // focused tests don't have to repeat boilerplate.
    final normalized = List<String>.from(roleIds);
    if (!normalized.contains('dealer')) {
      normalized.insert(0, 'dealer');
    }
    if (!normalized.contains('party_animal')) {
      normalized.add('party_animal');
    }
    if (!normalized.contains('wallflower')) {
      normalized.add('wallflower');
    }
    if (!normalized.contains('medic') && !normalized.contains('bouncer')) {
      normalized.add('medic');
    }

    // Ensure required roles exist and uniqueness constraints are respected.
    final usedUnique = <String>{};
    var idx = 1;
    for (final rid in normalized) {
      final role = _requireRole(rid);
      final isRepeatable = rid == 'dealer';
      if (!isRepeatable) {
        if (!usedUnique.add(rid)) {
          throw StateError('Duplicate unique role in test roster: $rid');
        }
      }
      final safeRoleLabel = rid.replaceAll(RegExp(r'[^A-Za-z0-9 ]+'), ' ');
      engine.addPlayer('P$idx $safeRoleLabel', role: role);
      idx++;
    }

    final validation = RoleValidator.validateGameSetup(engine.players);
    if (!validation.isValid) {
      throw StateError('Invalid test roster: ${validation.error}');
    }
    return engine;
  }

  bool _gameLogContains(GameEngine engine, String titleContains) {
    return engine.gameLog.any(
      (e) => e.title.toLowerCase().contains(titleContains.toLowerCase()),
    );
  }

  void _advanceToNextNight(GameEngine engine) {
    // Assumes we are currently in day phase.
    engine.skipToNextPhase();
    expect(engine.currentPhase, GamePhase.night);
  }

  void _advanceToNextDay(GameEngine engine) {
    // Assumes we are currently in night phase.
    engine.skipToNextPhase();
    expect(engine.currentPhase, GamePhase.day);
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
    required _ScriptPolicy policy,
  }) {
    // Special case for Medic Revive which might target a dead player
    if (actorRoleId == 'medic' && policy.medicReviveTargetRoleId != null) {
      final target = engine.players
          .where((p) => p.role.id == policy.medicReviveTargetRoleId)
          .firstOrNull;
      if (target != null) return target;
    }

    final preferredRoleId =
        policy.preferredTargetRoleIdByActorRoleId[actorRoleId];
    if (preferredRoleId != null) {
      final preferred = engine.players
          .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
          .where((p) => p.role.id == preferredRoleId)
          .firstOrNull;
      if (preferred != null) return preferred;
    }

    // Default: pick the first living non-host player.
    return engine.players
        .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
        .first;
  }

  /// Drives the script forward, answering interactive steps based on [policy].
  ///
  /// Stops once the engine reaches the Day Phase launcher step, or after
  /// [maxSteps] safety iterations.
  void _playScript(
    GameEngine engine, {
    required _ScriptPolicy policy,
    int maxSteps = 1200,
  }) {
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
        // No active step; advance phase.
        engine.advanceScript();
        safety++;
        continue;
      }

      switch (step.actionType) {
        case ScriptActionType.toggleOption:
          if (step.roleId == 'medic') {
            // Medic setup choice.
            engine.handleScriptOption(step, policy.medicSetupOption);
          } else if (step.roleId == 'wallflower' && step.id == 'wallflower_act') {
            // Wallflower witness style (host-entered flavor).
            engine.handleScriptOption(step, policy.wallflowerWitness ? 'PEEK' : 'SKIP');
          } else {
            // Default: choose a safe option.
            engine.handleScriptOption(step, 'SKIP');
          }
          engine.advanceScript();
          break;

        case ScriptActionType.binaryChoice:
          // Second Wind conversion decisions are handled here (host-only, next-night).
          if (step.roleId == 'dealer' &&
              (step.id == 'second_wind_conversion_choice' || step.id == 'second_wind_conversion_vote')) {
            engine.handleScriptAction(step, [policy.secondWindConvert ? 'CONVERT' : 'KILL']);
          } else {
            // Default: choose "no" to avoid unintended state changes.
            engine.handleScriptAction(step, ['no']);
          }
          engine.advanceScript();
          break;

        case ScriptActionType.selectTwoPlayers:
          final alive = engine.players
              .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
              .toList();
          if (alive.length >= 2) {
            engine.handleScriptAction(step, [alive[0].id, alive[1].id]);
          } else {
            engine.handleScriptAction(step, ['?']);
          }
          engine.advanceScript();
          break;

        case ScriptActionType.selectPlayer:
          final actorRoleId = step.roleId;
          if (actorRoleId == null) {
            // Some steps are selectPlayer but not tied to a role; do a best-effort pick.
            final target = _pickTarget(engine: engine, actorRoleId: 'unknown', policy: policy);
            engine.handleScriptAction(step, [target.id]);
            engine.advanceScript();
            break;
          }

          final target = _pickTarget(engine: engine, actorRoleId: actorRoleId, policy: policy);
          engine.handleScriptAction(step, [target.id]);
          engine.advanceScript();
          break;

        default:
          // Informational/optional steps can be advanced without selections.
          engine.advanceScript();
          break;
      }

      safety++;
    }

    if (safety >= maxSteps) {
      throw StateError('Script simulation exceeded maxSteps=$maxSteps (dayCount=${engine.dayCount}, phase=${engine.currentPhase}).');
    }
  }

  group('Role Coverage: Minimal Startability', () {
    test('Every role can be included in a valid game and start', () async {
      final roles = roleRepository.roles
          .where((r) => r.id != 'host' && r.id != 'temp')
          .toList();

      for (final role in roles) {
        final engine = _buildMinimalValidGameIncluding(role);
        final validation = RoleValidator.validateGameSetup(engine.players);
        expect(
          validation.isValid,
          isTrue,
          reason: 'Invalid setup when including roleId=${role.id}: ${validation.error}',
        );

        await engine.startGame();
        expect(engine.currentPhase, GamePhase.setup);
        expect(engine.scriptQueue, isNotEmpty);
      }
    });

    test('Variable roles start on start_alliance', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'second_wind',
        'creep',
      ]);
      await engine.startGame();

      final sw = _firstAliveByRoleId(engine, 'second_wind');
      expect(sw.alliance.toLowerCase().contains('party'), isTrue);

      // Creep has no start_alliance; it sets its alliance once it selects a
      // mimic target during the setup-night script.
      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'creep': 'party_animal',
          // Keep the Dealer from killing the Creep in this minimal flow.
          'dealer': 'wallflower',
        },
      );

      _playScript(engine, policy: policy, maxSteps: 250);
      final creepAfter = _firstAliveByRoleId(engine, 'creep');
      expect(creepAfter.alliance.toLowerCase().contains('party'), isTrue);
    });
  });

  group('Role Eventualities: Cross-Role Interactions', () {
    test('Clinger heartbreak + Creep inheritance does not break flow', () async {
      final engine = newEngine();
      await engine.createTestGame(fullRoster: true);
      await engine.startGame();

      final victim = _firstAliveByRoleId(engine, 'party_animal');
      final clinger = _firstAliveByRoleId(engine, 'clinger');
      final creepId = _firstAliveByRoleId(engine, 'creep').id;

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          // Setup night
          'clinger': 'party_animal',
          'creep': 'party_animal',
          'medic': 'medic',
          // Night 1
          'dealer': 'party_animal',
        },
      );

      _playScript(engine, policy: policy);

      expect(engine.deadPlayerIds, contains(victim.id));
      expect(engine.deadPlayerIds, contains(clinger.id));

      final creepAfter = engine.players.firstWhere((p) => p.id == creepId);
      expect(creepAfter.role.id, victim.role.id);
    });

    test('Second Wind conversion YES produces a new Dealer (next night, forfeits kill)', () async {
      final engine = newEngine();
      await engine.createTestGame(fullRoster: true);
      await engine.startGame();

      final secondWindId = _firstAliveByRoleId(engine, 'second_wind').id;

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: true,
        preferredTargetRoleIdByActorRoleId: {
          // Ensure Dealers try to kill Second Wind on Night 1.
          'dealer': 'second_wind',
          // Ensure Medic doesn't protect Second Wind.
          'medic': 'medic',
        },
      );

      _playScript(engine, policy: policy);

      // After Night 1 resolves, Second Wind should be dead but eligible for conversion next night.
      expect(engine.deadPlayerIds, contains(secondWindId));

      // Skip Day 1 (vote) and start Night 2.
      _advanceToNextNight(engine);

      // Advance until we reach the conversion step (injected before Dealer kill).
      var safety = 0;
      while (engine.currentScriptStep?.id != 'second_wind_conversion_choice' && safety < 500) {
        engine.advanceScript();
        safety++;
      }
      expect(engine.currentScriptStep?.id, 'second_wind_conversion_choice');

      // Convert: should revive as Dealer and skip Dealer kill.
      engine.handleScriptAction(engine.currentScriptStep!, ['CONVERT']);
      engine.advanceScript();

      final sw = engine.players.firstWhere((p) => p.id == secondWindId);
      expect(sw.secondWindConverted, isTrue);
      expect(sw.role.id, 'dealer');
      expect(sw.isAlive, isTrue);
      expect(engine.currentScriptStep?.id, isNot('dealer_act'));
    });

    test('Second Wind conversion NO keeps them dead (kill proceeds)', () async {
      final engine = newEngine();
      await engine.createTestGame(fullRoster: true);
      await engine.startGame();

      final secondWindId = _firstAliveByRoleId(engine, 'second_wind').id;

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'dealer': 'second_wind',
          'medic': 'medic',
        },
      );

      _playScript(engine, policy: policy);

      // After Night 1 resolves, Second Wind should be dead and eligible for conversion next night.
      expect(engine.deadPlayerIds, contains(secondWindId));

      // Skip Day 1 and start Night 2.
      _advanceToNextNight(engine);

      var safety = 0;
      while (engine.currentScriptStep?.id != 'second_wind_conversion_choice' && safety < 500) {
        engine.advanceScript();
        safety++;
      }
      expect(engine.currentScriptStep?.id, 'second_wind_conversion_choice');

      // Kill instead: do not convert; Dealer kill step should still occur.
      engine.handleScriptAction(engine.currentScriptStep!, ['KILL']);
      engine.advanceScript();

      final sw = engine.players.firstWhere((p) => p.id == secondWindId);
      expect(engine.deadPlayerIds, contains(secondWindId));
      expect(sw.isAlive, isFalse);
      expect(engine.currentScriptStep?.id, 'dealer_act');
    });
  });

  group('Role Eventualities: Engine Branch Coverage', () {
    test('Minor cannot die to Dealer kill until ID’d', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'bouncer',
        'minor',
      ]);
      await engine.startGame();

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          // Ensure Dealers target the Minor.
          'dealer': 'minor',
          // Ensure Bouncer does NOT ID the Minor.
          'bouncer': 'party_animal',
        },
      );

      _playScript(engine, policy: policy);

      final minor = engine.players.firstWhere((p) => p.role.id == 'minor');
      expect(minor.isAlive, isTrue);
      expect(engine.deadPlayerIds, isNot(contains(minor.id)));
    });

    test('Minor becomes killable after being ID’d', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'bouncer',
        'minor',
      ]);
      await engine.startGame();

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          // Dealers still target the Minor.
          'dealer': 'minor',
          // Bouncer IDs the Minor (making them vulnerable).
          'bouncer': 'minor',
        },
      );

      _playScript(engine, policy: policy);

      final minor = engine.players.firstWhere((p) => p.role.id == 'minor');
      expect(minor.minorHasBeenIDd, isTrue);
      expect(minor.isAlive, isFalse);
      expect(engine.deadPlayerIds, contains(minor.id));
    });

    test('Bouncer successfully steals Roofi ability on correct challenge',
        () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'bouncer',
        'roofi',
        'medic',
      ]);
      await engine.startGame();

      final bouncer = engine.players.firstWhere((p) => p.role.id == 'bouncer');
      final roofi = engine.players.firstWhere((p) => p.role.id == 'roofi');

      final ok = engine.resolveBouncerRoofiChallenge(roofi.id);
      expect(ok, isTrue);
      expect(roofi.roofiAbilityRevoked, isTrue);
      expect(bouncer.bouncerHasRoofiAbility, isTrue);
      expect(bouncer.bouncerAbilityRevoked, isFalse);

      // With stolen powers, the Roofi action should still be usable.
      final target = engine.players.firstWhere(
        (p) => p.isAlive && p.isEnabled && p.role.id != 'host' && p.id != bouncer.id,
      );
      engine.handleScriptAction(
        ScriptStep(
          id: 'bouncer_roofi_act',
          title: 'Stolen Roofi Powers',
          readAloudText: '',
          instructionText: '',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'roofi',
        ),
        [target.id],
      );
      expect(engine.nightActions['roofi'], target.id);
      expect(target.silencedDay, engine.dayCount + 1);
    });

    test('Bouncer loses ID check ability on incorrect Roofi challenge',
        () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'bouncer',
        'roofi',
        'medic',
      ]);
      await engine.startGame();

      final bouncer = engine.players.firstWhere((p) => p.role.id == 'bouncer');
      final innocent = engine.players.firstWhere(
        (p) => p.isAlive && p.isEnabled && p.role.id == 'party_animal',
      );

      final ok = engine.resolveBouncerRoofiChallenge(innocent.id);
      expect(ok, isTrue);
      expect(bouncer.bouncerAbilityRevoked, isTrue);
      expect(bouncer.bouncerHasRoofiAbility, isFalse);

      // Defensive: even if a host/UI calls the ID-check action, it should not apply.
      final target = engine.players.firstWhere(
        (p) => p.isAlive && p.isEnabled && p.role.id != 'host' && p.id != bouncer.id,
      );
      expect(target.idCheckedByBouncer, isFalse);
      engine.handleScriptAction(
        ScriptStep(
          id: 'bouncer_act',
          title: 'The ID Check',
          readAloudText: '',
          instructionText: '',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'bouncer',
        ),
        [target.id],
      );
      expect(engine.nightActions['bouncer_check'], isNot(target.id));
      expect(target.idCheckedByBouncer, isFalse);
    });

    test('Medic PROTECT prevents Dealer kill', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
      ]);
      await engine.startGame();

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'dealer': 'party_animal',
          'medic': 'party_animal',
        },
      );

      _playScript(engine, policy: policy);
      // Clean recap should not leak role names; host recap can.
      expect(engine.lastNightHostRecap.toLowerCase(), contains('medic'));
      expect(engine.deadPlayerIds.length, 0);
    });

    test('Medic REVIVE can resurrect a dead player same night', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
      ]);
      await engine.startGame();

      // Night 1: dealer kills a party animal; medic chose REVIVE.
      // We configure policy to kill party_animal AND medic to revive party_animal.
      final policyNight1 = _ScriptPolicy(
        medicSetupOption: 'REVIVE',
        wallflowerWitness: false,
        secondWindConvert: false,
        medicReviveTargetRoleId: 'party_animal',
        preferredTargetRoleIdByActorRoleId: {
          'dealer': 'party_animal',
        },
      );
      _playScript(engine, policy: policyNight1);

      final revived = engine.players.firstWhere((p) => p.role.id == 'party_animal');
      final medic = engine.players.firstWhere((p) => p.role.id == 'medic');

      // Since _playScript already resolved the night (it reaches showDayScene),
      // we can check results immediately.
      expect(revived.isAlive, isTrue);
      expect(engine.deadPlayerIds, isNot(contains(revived.id)));
      expect(medic.reviveUsed, isTrue); // consumed
      expect(
        engine.lastNightSummary.toLowerCase(),
        contains('returned from the dead'),
      );
    });

    test('Medic setup choice is locked after Night 1 selection', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
      ]);
      await engine.startGame();

      final medic = engine.players.firstWhere((p) => p.role.id == 'medic');

      engine.handleScriptOption(
        ScriptStep(
          id: 'medic_setup_choice',
          title: 'The Medic - Setup',
          readAloudText: '',
          instructionText: '',
          actionType: ScriptActionType.toggleOption,
          roleId: 'medic',
        ),
        'PROTECT',
      );
      expect(medic.medicChoice, 'PROTECT_DAILY');

      // Attempt to change later should be ignored.
      engine.handleScriptOption(
        ScriptStep(
          id: 'medic_setup_choice',
          title: 'The Medic - Setup',
          readAloudText: '',
          instructionText: '',
          actionType: ScriptActionType.toggleOption,
          roleId: 'medic',
        ),
        'REVIVE',
      );
      expect(medic.medicChoice, 'PROTECT_DAILY');
    });

    test('Medic REVIVE cannot resurrect a Dealer', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
      ]);
      await engine.startGame();

      // Night 1: choose REVIVE.
      final policyNight1 = _ScriptPolicy(
        medicSetupOption: 'REVIVE',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'dealer': 'party_animal',
        },
      );
      _playScript(engine, policy: policyNight1);

      // Kill the Dealer during the day.
      final dealer = engine.players.firstWhere((p) => p.role.id == 'dealer');
      engine.processDeath(dealer, cause: 'vote');
      expect(dealer.isAlive, isFalse);

      engine.nightActions['medic_revive'] = dealer.id;
      _advanceToNextNight(engine);
      _advanceToNextDay(engine);

      final medic = engine.players.firstWhere((p) => p.role.id == 'medic');
      expect(dealer.isAlive, isFalse);
      expect(medic.reviveUsed, isFalse);
      expect(engine.lastNightSummary.toLowerCase(), isNot(contains('miracle')));
    });

    test('Medic REVIVE can resurrect themselves even if dead', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
      ]);
      await engine.startGame();

      // Night 1: choose REVIVE.
      final policyNight1 = _ScriptPolicy(
        medicSetupOption: 'REVIVE',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'dealer': 'party_animal',
        },
      );
      _playScript(engine, policy: policyNight1);

      final medic = engine.players.firstWhere((p) => p.role.id == 'medic');
      engine.processDeath(medic, cause: 'vote');
      expect(medic.isAlive, isFalse);

      engine.nightActions['medic_revive'] = medic.id;
      _advanceToNextNight(engine);
      _advanceToNextDay(engine);

      expect(medic.isAlive, isTrue);
      expect(medic.reviveUsed, isTrue);
      expect(engine.deadPlayerIds, isNot(contains(medic.id)));
    });

    test('Dead Medic cannot resurrect other players', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
      ]);
      await engine.startGame();

      final policyNight1 = _ScriptPolicy(
        medicSetupOption: 'REVIVE',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'dealer': 'party_animal',
        },
      );
      _playScript(engine, policy: policyNight1);

      final medic = engine.players.firstWhere((p) => p.role.id == 'medic');
      // With Party Animal now unique, pick another living non-dealer target.
      final target = engine.players.firstWhere(
        (p) => p.role.id == 'wallflower' && p.isAlive,
      );

      engine.processDeath(medic, cause: 'vote');
      engine.processDeath(target, cause: 'vote');
      expect(medic.isAlive, isFalse);
      expect(target.isAlive, isFalse);

      engine.nightActions['medic_revive'] = target.id;
      _advanceToNextNight(engine);
      _advanceToNextDay(engine);

      expect(target.isAlive, isFalse);
      expect(medic.reviveUsed, isFalse);
    });

    test('Sober sending Dealer home prevents Dealer murder', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'sober',
      ]);
      await engine.startGame();

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'sober': 'dealer',
          'dealer': 'party_animal',
        },
      );

      _playScript(engine, policy: policy);
      expect(engine.deadPlayerIds, isEmpty);
      expect(engine.lastNightSummary.toLowerCase(), contains('no murders'));
    });

    test('Sober sending someone home protects them from Dealer kill', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'sober',
      ]);
      await engine.startGame();

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'sober': 'party_animal',
          'dealer': 'party_animal',
        },
      );

      _playScript(engine, policy: policy);
      expect(engine.deadPlayerIds, isEmpty);
      expect(engine.lastNightSummary.toLowerCase(), contains('sent'));
    });

    test('Sober sent-home player cannot vote during the day', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'sober',
      ]);
      await engine.startGame();

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'sober': 'party_animal',
          'dealer': 'party_animal',
        },
      );

      _playScript(engine, policy: policy);
      expect(engine.currentPhase, GamePhase.day);

      final sentHome = engine.players.firstWhere(
        (p) => p.isAlive && p.isEnabled && p.soberSentHome,
        orElse: () => throw StateError('Expected a sent-home player.'),
      );
      final dealer = engine.players.firstWhere((p) => p.role.id == 'dealer');

      engine.setDayVote(voterId: sentHome.id, targetId: dealer.id);
      expect(engine.currentDayVotesByVoter[sentHome.id], isNull);

      // Sanity: another player can vote.
      final otherVoter = engine.players.firstWhere(
        (p) => p.isAlive && p.isEnabled && !p.soberSentHome && p.role.id != 'host',
      );
      engine.setDayVote(voterId: otherVoter.id, targetId: dealer.id);
      expect(engine.currentDayVotesByVoter[otherVoter.id], dealer.id);
    });

    test('Day vote tally ignores sent-home voters defensively', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'sober',
      ]);
      await engine.startGame();

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'sober': 'party_animal',
          'dealer': 'party_animal',
        },
      );

      _playScript(engine, policy: policy);
      expect(engine.currentPhase, GamePhase.day);

      final sentHome = engine.players.firstWhere(
        (p) => p.isAlive && p.isEnabled && p.soberSentHome,
        orElse: () => throw StateError('Expected a sent-home player.'),
      );
      final dealer = engine.players.firstWhere((p) => p.role.id == 'dealer');

      // Bypass recordVote and mutate the raw maps directly.
      engine.currentDayVotesByVoter[sentHome.id] = dealer.id;
      engine.currentDayVotesByTarget[dealer.id] = [sentHome.id];

      expect(engine.eligibleDayVotesByTarget[dealer.id], isNull);
    });

    test('Seasoned Drinker burns a life only on Dealer kill attempts', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'dealer',
        'seasoned_drinker',
        'party_animal',
        'medic',
      ]);
      await engine.startGame();

      final drinker = engine.players.firstWhere(
        (p) => p.role.id == 'seasoned_drinker',
      );
      expect(drinker.lives, 3);

      engine.processDeath(drinker, cause: 'dealer_kill');
      expect(drinker.isAlive, isTrue);
      expect(drinker.lives, 2);
    });

    test('Seasoned Drinker burns a life on night_kill_special', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'dealer',
        'seasoned_drinker',
        'party_animal',
        'medic',
      ]);
      await engine.startGame();

      final drinker = engine.players.firstWhere(
        (p) => p.role.id == 'seasoned_drinker',
      );
      expect(drinker.lives, 3);

      engine.processDeath(drinker, cause: 'night_kill_special');
      expect(drinker.isAlive, isTrue);
      expect(drinker.lives, 2);
    });

    test('Seasoned Drinker extra lives do not apply to non-Dealer night kills',
        () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'dealer',
        'seasoned_drinker',
        'party_animal',
        'medic',
      ]);
      await engine.startGame();

      final drinker = engine.players.firstWhere(
        (p) => p.role.id == 'seasoned_drinker',
      );
      expect(drinker.lives, 3);

      engine.processDeath(drinker, cause: 'clinger_attack_dog');
      expect(drinker.isAlive, isFalse);
      expect(drinker.lives, 3);
    });

    test('Roofi blocks single Dealer on following night and silences next day',
        () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'roofi',
      ]);
      await engine.startGame();

      final policyNight1 = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'roofi': 'dealer',
          'dealer': 'party_animal',
          'medic': 'medic',
        },
      );
      _playScript(engine, policy: policyNight1);

      final dealer = engine.players.firstWhere((p) => p.role.id == 'dealer');
      expect(dealer.blockedKillNight, isNotNull);

      // Day -> Night 2
      _advanceToNextNight(engine);

      // New Behavior: Dealer is NOT blocked from waking up. Logic handles failure.
      expect(
        engine.scriptQueue.any((s) => s.id == 'dealer_blocked'),
        isFalse,
      );
      expect(
        engine.scriptQueue.any((s) => s.id == 'dealer_kill' || s.id == 'dealer_act'),
        isTrue,
      );

      // Night 2 -> Day 2 (report should include silence)
      _advanceToNextDay(engine);
      expect(engine.lastNightSummary.toLowerCase(), contains('silenced'));
    });

    test('Roofi silenced player cannot vote during silenced day', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'roofi',
      ]);
      await engine.startGame();

      final policyNight1 = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          // Silence the Dealer so the silenced player is guaranteed alive during the day.
          'roofi': 'dealer',
          'dealer': 'party_animal',
          'medic': 'medic',
        },
      );
      _playScript(engine, policy: policyNight1);

      // We should now be at the Day Scene launcher.
      expect(engine.currentPhase, GamePhase.day);

      final silenced = engine.players
          .where(
              (p) => p.isAlive && p.isEnabled && p.silencedDay == engine.dayCount)
          .firstOrNull;
      expect(silenced, isNotNull);

      final target = engine.players.firstWhere(
        (p) => p.isAlive && p.isEnabled && p.role.id != 'host' && p.id != silenced!.id,
      );
      engine.recordVote(voterId: silenced!.id, targetId: target.id);

      // Vote should be rejected and not recorded.
      expect(engine.currentDayVotesByVoter[silenced.id], isNull);
      expect(engine.eligibleDayVotesByTarget.containsKey(target.id), isFalse);
    });

    test('Roofi prevents a roofi\'d player from acting later that night',
        () async {
      final engine = _buildGameWithRoles(roleIds: [
        'party_animal',
        'roofi',
        'bartender',
      ]);
      await engine.startGame();

      // Put the engine in a night context for direct step handling.
      engine.currentPhase = GamePhase.night;
      engine.dayCount = 1;

      final roofi = engine.players.firstWhere((p) => p.role.id == 'roofi');
      final bartender = engine.players.firstWhere((p) => p.role.id == 'bartender');
      final pa = engine.players.firstWhere((p) => p.role.id == 'party_animal');

      const roofiStep = ScriptStep(
        id: 'roofi_act',
        title: 'The Roofi',
        readAloudText: 'Roofi, select a player to paralyze.',
        instructionText: 'Select a player.',
        actionType: ScriptActionType.selectPlayer,
        roleId: 'roofi',
      );

      const bartenderStep = ScriptStep(
        id: 'bartender_act',
        title: 'The Bartender',
        readAloudText: 'Bartender, select two players.',
        instructionText: 'Select two players.',
        actionType: ScriptActionType.selectTwoPlayers,
        roleId: 'bartender',
      );

      // Roofi targets Bartender; this should paralyze Bartender for the rest of the night.
      engine.handleScriptAction(roofiStep, [bartender.id]);
      expect(bartender.silencedDay, engine.dayCount + 1);

      // Bartender now tries to act; it should be blocked.
      engine.handleScriptAction(bartenderStep, [pa.id, roofi.id]);
      expect(engine.nightActions.containsKey('bartender_a'), isFalse);
      expect(engine.nightActions.containsKey('bartender_b'), isFalse);
    });

    test('Predator retaliation captures voters and can kill an eligible voter',
        () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'predator',
      ]);
      await engine.startGame();

      // Jump to day phase quickly (finish setup+night).
      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
      );
      _playScript(engine, policy: policy);

      final predator = engine.players.firstWhere((p) => p.role.id == 'predator');
      final voter = engine.players.firstWhere(
        (p) => p.isAlive && p.role.id != 'predator' && p.role.id != 'host',
      );

      // Simulate a vote against Predator.
      engine.recordVote(voterId: voter.id, targetId: predator.id);

      // Mark a preferred target (optional) and vote Predator out.
      engine.nightActions['predator_mark'] = voter.id;
      engine.voteOutPlayer(predator.id);

      expect(engine.pendingPredatorId, predator.id);
      expect(engine.pendingPredatorEligibleVoterIds, contains(voter.id));

      final ok = engine.completePredatorRetaliation(voter.id);
      expect(ok, isTrue);
      expect(engine.deadPlayerIds, contains(voter.id));
    });

    test(
        'Predator retaliation can still target the marked player even if they were sent home/silenced (not an eligible voter)',
        () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'predator',
        'sober',
        'roofi',
      ]);
      await engine.startGame();

      // Jump to day phase quickly (finish setup+night).
      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
      );
      _playScript(engine, policy: policy);

      final predator = engine.players.firstWhere((p) => p.role.id == 'predator');
      final voter = engine.players.firstWhere(
        (p) => p.isAlive && p.role.id == 'party_animal',
      );
      final marked = engine.players.firstWhere((p) => p.role.id == 'medic');

      // Marked player is driven home/paralyzed today (cannot vote), but should
      // still be a valid retaliation target.
      marked.soberSentHome = true;
      marked.silencedDay = engine.dayCount;

      // Only the eligible voter votes Predator out.
      engine.recordVote(voterId: voter.id, targetId: predator.id);

      // Predator marks the non-voter target.
      engine.nightActions['predator_mark'] = marked.id;
      engine.voteOutPlayer(predator.id);

      expect(engine.pendingPredatorId, predator.id);
      expect(engine.pendingPredatorEligibleVoterIds, contains(voter.id));
      expect(engine.pendingPredatorPreferredTargetId, marked.id);

      final ok = engine.completePredatorRetaliation(marked.id);
      expect(ok, isTrue);
      expect(engine.deadPlayerIds, contains(marked.id));
    });

    test('Drama Queen death sets swap pending and completeDramaQueenSwap swaps roles',
        () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'drama_queen',
        'club_manager',
      ]);
      await engine.startGame();

      // Move to day.
      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
      );
      _playScript(engine, policy: policy);

      final dq = engine.players.firstWhere((p) => p.role.id == 'drama_queen');
      engine.processDeath(dq, cause: 'vote');
      expect(engine.dramaQueenSwapPending, isTrue);

      final a = engine.players.firstWhere((p) => p.role.id == 'club_manager');
      final b = engine.players.firstWhere((p) => p.role.id == 'party_animal');
      final roleA = a.role.id;
      final roleB = b.role.id;

      final record = engine.completeDramaQueenSwap(a, b);
      expect(record, isNotNull);
      expect(a.role.id, roleB);
      expect(b.role.id, roleA);
      expect(engine.dramaQueenSwapPending, isFalse);
    });

    test('Tea Spiller reveal logs when Tea Spiller dies', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'tea_spiller',
      ]);
      await engine.startGame();

      // Move to day.
      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
      );
      _playScript(engine, policy: policy);

      final tea = engine.players.firstWhere((p) => p.role.id == 'tea_spiller');

      // Tea Spiller may only target players who voted for them.
      final voterA = engine.players.firstWhere((p) => p.role.id == 'dealer');
      final voterB = engine.players.firstWhere((p) => p.role.id == 'party_animal');
      engine.recordVote(voterId: voterA.id, targetId: tea.id);
      engine.recordVote(voterId: voterB.id, targetId: tea.id);

      engine.processDeath(tea, cause: 'vote');

      expect(engine.hasPendingTeaSpillerReveal, isTrue);

      // Must pick among voters.
      expect(engine.pendingTeaSpillerEligibleVoterIds, containsAll([voterA.id, voterB.id]));
      expect(engine.completeTeaSpillerReveal(voterA.id), isTrue);

      expect(_gameLogContains(engine, 'Tea Spilled'), isTrue);
    });

    test('Clinger attack-dog kill is immediate and one-time', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'medic',
        'clinger',
      ]);

      // Force Clinger into attack-dog mode before night script is built.
      final clinger = engine.players.firstWhere((p) => p.role.id == 'clinger');
      clinger.clingerFreedAsAttackDog = true;
      clinger.clingerAttackDogUsed = false;

      await engine.startGame();

      final policy = _ScriptPolicy(
        medicSetupOption: 'PROTECT',
        wallflowerWitness: false,
        secondWindConvert: false,
        preferredTargetRoleIdByActorRoleId: {
          'clinger': 'party_animal',
          'medic': 'medic',
          'dealer': 'medic',
        },
      );

      _playScript(engine, policy: policy);

      final deadParty = engine.players
          .where((p) => p.role.id == 'party_animal' && !p.isAlive)
          .toList();
      expect(deadParty, isNotEmpty);
      expect(clinger.clingerAttackDogUsed, isTrue);
    });

    test('Club Manager can privately view a fellow player role (callback fires)',
        () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'club_manager',
        'medic',
      ]);
      await engine.startGame();

      final clubManager =
          engine.players.firstWhere((p) => p.role.id == 'club_manager');
      final target = engine.players.firstWhere(
        (p) =>
            p.isAlive &&
            p.isEnabled &&
            p.id != clubManager.id &&
            p.role.id != 'host',
      );

      Player? revealed;
      engine.onClubManagerReveal = (p) => revealed = p;

      engine.handleScriptAction(
        ScriptStep(
          id: 'club_manager_act',
          title: 'View Role Card',
          readAloudText: '',
          instructionText: '',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'club_manager',
        ),
        [target.id],
      );

      expect(revealed?.id, target.id);
      expect(
        engine.gameLog.any(
          (e) => e.description.toLowerCase().contains('club manager viewed'),
        ),
        isTrue,
      );
    });

    test('Club Manager cannot select themselves to view role', () async {
      final engine = _buildGameWithRoles(roleIds: [
        'dealer',
        'party_animal',
        'club_manager',
        'medic',
      ]);
      await engine.startGame();

      final clubManager =
          engine.players.firstWhere((p) => p.role.id == 'club_manager');

      Player? revealed;
      engine.onClubManagerReveal = (p) => revealed = p;

      engine.handleScriptAction(
        ScriptStep(
          id: 'club_manager_act',
          title: 'View Role Card',
          readAloudText: '',
          instructionText: '',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'club_manager',
        ),
        [clubManager.id],
      );

      expect(revealed, isNull);
      expect(
        engine.gameLog.any(
          (e) => e.description.toLowerCase().contains('fellow player'),
        ),
        isTrue,
      );
    });
  });
}
