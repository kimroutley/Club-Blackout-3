import 'package:club_blackout/logic/game_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/file_role_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameEngine gameEngine;
  late FileRoleRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = FileRoleRepository();
    await repo.loadRoles();
    gameEngine = GameEngine(roleRepository: repo);

    // Setup: 1 Dealer, 1 Whore, 1 Party Animal, 1 Wallflower (Party-aligned)
    gameEngine.addPlayer('Dealer1', role: repo.getRoleById('dealer'));
    gameEngine.addPlayer('Whore1', role: repo.getRoleById('whore'));
    gameEngine.addPlayer('PA1', role: repo.getRoleById('party_animal'));
    gameEngine.addPlayer('WF1', role: repo.getRoleById('wallflower'));
    await gameEngine.startGame();
  });

  void advanceToNightOne() {
    int safety = 0;
    while (gameEngine.currentPhase != GamePhase.night && safety < 600) {
      gameEngine.advanceScript();
      safety++;
    }
    if (gameEngine.currentPhase != GamePhase.night) {
      throw StateError('Failed to reach Night 1.');
    }
  }

  void executeStep(String roleId, List<String> targetIds) {
    final step = gameEngine.scriptQueue.firstWhere(
      (s) => s.roleId == roleId,
      orElse: () => throw Exception('Step not found for $roleId'),
    );
    gameEngine.handleScriptAction(step, targetIds);
  }

  void advanceToDay() {
    int safety = 0;
    while (gameEngine.currentPhase != GamePhase.day && safety < 800) {
      gameEngine.advanceScript();
      safety++;
    }
    if (gameEngine.currentPhase != GamePhase.day) {
      throw StateError('Failed to reach Day phase.');
    }
  }

  void advanceToNextNight() {
    int safety = 0;
    while (gameEngine.currentPhase != GamePhase.night && safety < 1200) {
      gameEngine.advanceScript();
      safety++;
    }
    if (gameEngine.currentPhase != GamePhase.night) {
      throw StateError('Failed to reach next Night phase.');
    }
  }

  test('Whore deflection saves a Dealer from being voted out', () {
    advanceToNightOne();
    final dealer = gameEngine.players.firstWhere((p) => p.role.id == 'dealer');
    final target =
        gameEngine.players.firstWhere((p) => p.role.id == 'wallflower');
    final whore = gameEngine.players.firstWhere((p) => p.role.id == 'whore');

    // Night phase: Whore deflects to target
    executeStep('whore', [target.id]);
    expect(whore.whoreDeflectionTargetId, target.id);

    // Day phase: Dealer is voted out
    gameEngine.voteOutPlayer(dealer.id);

    // Assertions
    expect(dealer.isAlive, isTrue,
        reason: 'Dealer should be alive after deflection');
    expect(target.isAlive, isFalse,
      reason: 'Target should be dead after being deflected to');
    expect(
      gameEngine.gameLog.any((log) => log.title == 'Vote Deflection'),
      isTrue,
    );
  });

  test('Whore deflection saves the Whore from being voted out', () {
    advanceToNightOne();
    final whore = gameEngine.players.firstWhere((p) => p.role.id == 'whore');
    final target =
      gameEngine.players.firstWhere((p) => p.role.id == 'wallflower');

    // Night phase: Whore deflects to target
    executeStep('whore', [target.id]);
    expect(whore.whoreDeflectionTargetId, target.id);

    // Day phase: Whore is voted out
    gameEngine.voteOutPlayer(whore.id);

    // Assertions
    expect(whore.isAlive, isTrue,
        reason: 'Whore should be alive after deflecting vote');
    expect(target.isAlive, isFalse,
      reason: 'Target should be dead after being deflected to');
    expect(
      gameEngine.gameLog.any((log) => log.title == 'Vote Deflection'),
      isTrue,
    );
  });

  test('Whore deflection does NOT trigger if a Party Animal is voted out', () {
    advanceToNightOne();
    final pa1 =
        gameEngine.players.firstWhere((p) => p.role.id == 'party_animal');
    final target =
        gameEngine.players.firstWhere((p) => p.role.id == 'wallflower');
    final whore = gameEngine.players.firstWhere((p) => p.role.id == 'whore');

    // Night phase: Whore deflects to target
    executeStep('whore', [target.id]);
    expect(whore.whoreDeflectionTargetId, target.id);

    // Day phase: A party animal is voted out
    gameEngine.voteOutPlayer(pa1.id);

    // Assertions
    expect(pa1.isAlive, isFalse, reason: 'PA1 should be dead');
    expect(target.isAlive, isTrue,
        reason:
            "Target should still be alive, deflection shouldn't have happened");
    expect(
      gameEngine.gameLog.any((log) => log.title == 'Vote Deflection'),
      isFalse,
    );
  });

  test('Whore is only asked to pick once (no repeat prompt on later nights)', () {
    advanceToNightOne();

    expect(
      gameEngine.scriptQueue.any((s) => s.id == 'whore_deflect'),
      isTrue,
      reason: 'Night 1 should include the Whore deflection selection step.',
    );

    final target =
        gameEngine.players.firstWhere((p) => p.role.id == 'wallflower');

    executeStep('whore', [target.id]);

    final whore = gameEngine.players.firstWhere((p) => p.role.id == 'whore');
    expect(whore.whoreDeflectionTargetId, target.id);

    // Finish Night 1, then advance through Day 1 into Night 2.
    advanceToDay();
    advanceToNextNight();

    expect(
      gameEngine.scriptQueue.any((s) => s.id == 'whore_deflect'),
      isFalse,
      reason:
          'Once a Whore has chosen a scapegoat, the game should not ask again on later nights.',
    );
  });

  test(
      'Whore prompt returns if a new player becomes Whore (Creep inheritance)',
      () async {
    SharedPreferences.setMockInitialValues({});

    final engine = GameEngine(roleRepository: repo);

    // Setup: 1 Dealer, 1 Whore, 1 Creep, 1 Wallflower
    engine.addPlayer('Dealer1', role: repo.getRoleById('dealer'));
    engine.addPlayer('Whore1', role: repo.getRoleById('whore'));
    engine.addPlayer('Creep1', role: repo.getRoleById('creep'));
    engine.addPlayer('WF1', role: repo.getRoleById('wallflower'));
    await engine.startGame();

    void advanceToNightOne() {
      int safety = 0;
      while (engine.currentPhase != GamePhase.night && safety < 600) {
        engine.advanceScript();
        safety++;
      }
      if (engine.currentPhase != GamePhase.night) {
        throw StateError('Failed to reach Night 1.');
      }
    }

    void executeStep(String roleId, List<String> targetIds) {
      final step = engine.scriptQueue.firstWhere(
        (s) => s.roleId == roleId,
        orElse: () => throw Exception('Step not found for $roleId'),
      );
      engine.handleScriptAction(step, targetIds);
    }

    void advanceToDay() {
      int safety = 0;
      while (engine.currentPhase != GamePhase.day && safety < 800) {
        engine.advanceScript();
        safety++;
      }
      if (engine.currentPhase != GamePhase.day) {
        throw StateError('Failed to reach Day phase.');
      }
    }

    void advanceToNextNight() {
      int safety = 0;
      while (engine.currentPhase != GamePhase.night && safety < 1200) {
        engine.advanceScript();
        safety++;
      }
      if (engine.currentPhase != GamePhase.night) {
        throw StateError('Failed to reach next Night phase.');
      }
    }

    advanceToNightOne();

    final originalWhore =
        engine.players.firstWhere((p) => p.role.id == 'whore');
    final creep = engine.players.firstWhere((p) => p.role.id == 'creep');
    final target = engine.players.firstWhere((p) => p.role.id == 'wallflower');

    // Ensure the original Whore has already locked in a target.
    expect(
      engine.scriptQueue.any((s) => s.id == 'whore_deflect'),
      isTrue,
      reason: 'Night 1 should include the Whore deflection selection step.',
    );
    executeStep('whore', [target.id]);
    expect(originalWhore.whoreDeflectionTargetId, target.id);

    // Set the Creep to inherit the Whore role when the Whore dies.
    creep.creepTargetId = originalWhore.id;

    // Kill the Whore; the Creep should inherit the Whore role.
    engine.processDeath(originalWhore, cause: 'night_kill');
    expect(originalWhore.isAlive, isFalse);

    final inheritedWhore = engine.players.firstWhere((p) => p.id == creep.id);
    expect(inheritedWhore.role.id, 'whore');
    expect(
      inheritedWhore.whoreDeflectionTargetId,
      isNull,
      reason:
          'A new Whore-holder should not inherit the previous Whore\'s locked target.',
    );

    // On the next night, the game should prompt again (for the new Whore-holder).
    advanceToDay();
    advanceToNextNight();

    expect(
      engine.scriptQueue.any((s) => s.id == 'whore_deflect'),
      isTrue,
      reason:
          'When a different player becomes the Whore, the Whore deflection prompt should appear again.',
    );
  });
}
