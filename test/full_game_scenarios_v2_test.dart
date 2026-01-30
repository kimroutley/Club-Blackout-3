import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/script_step.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/file_role_repository.dart';

// This test suite uses the full roles roster from assets/data/roles.json.
// Each scenario is executed in a full-roster game so every character is present.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameEngine gameEngine;
  late FileRoleRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = FileRoleRepository();
    await repo.loadRoles();
    gameEngine = GameEngine(roleRepository: repo);

    // Include all characters as players in every scenario.
    await gameEngine.createTestGame(fullRoster: true);
    await gameEngine.startGame();
  });

  String idOfRole(String roleId) =>
      gameEngine.players.firstWhere((p) => p.role.id == roleId).id;

  void executeScriptStep(String roleIdFilter, List<String> targetIds) {
    bool found = false;
    int maxSteps = 500;
    while (gameEngine.currentScriptIndex < gameEngine.scriptQueue.length &&
        maxSteps > 0) {
      final currentStep = gameEngine.scriptQueue[gameEngine.currentScriptIndex];
      // Debug print
      // print('Step: ${currentStep.id} Role: ${currentStep.roleId} Action: ${currentStep.actionType}');

      if (currentStep.roleId == roleIdFilter &&
          currentStep.actionType == ScriptActionType.selectPlayer) {
        gameEngine.handleScriptAction(currentStep, targetIds);
        found = true;
      }

      gameEngine.advanceScript();
      maxSteps--;

      if (found) return;
    }
    if (!found) {
      throw Exception(
        'Script step for $roleIdFilter not found in queue of length ${gameEngine.scriptQueue.length}. Queue dump: ${gameEngine.scriptQueue.map((s) => s.roleId).toList()}',
      );
    }
  }

  void fastForwardScript() {
    int safety = 0;
    final int initialPhaseDay = gameEngine.dayCount;
    final GamePhase initialPhase = gameEngine.currentPhase;

    while (gameEngine.currentScriptIndex < gameEngine.scriptQueue.length &&
        safety < 500) {
      gameEngine.advanceScript();
      safety++;
      if (gameEngine.currentPhase != initialPhase ||
          gameEngine.dayCount != initialPhaseDay) {
        break;
      }
    }
  }

  test('Scenario 1: Dealer kills Party Animal', () async {
    final medic = gameEngine.players.firstWhere((p) => p.role.id == 'medic');
    final victimId = idOfRole('party_animal');
    medic.medicChoice = 'PROTECT_DAILY';

    fastForwardScript(); // End Setup -> Night 1

    executeScriptStep('dealer', [victimId]);
    executeScriptStep('medic', [medic.id]);

    fastForwardScript(); // End Night 1 -> Day

    expect(gameEngine.deadPlayerIds, contains(victimId));
  });

  test('Scenario 3: Clinger dies with Partner', () async {
    final partnerId = idOfRole('party_animal');
    final clingerId = idOfRole('clinger');
    executeScriptStep('clinger', [partnerId]);
    fastForwardScript(); // End Setup -> Night 1

    executeScriptStep('dealer', [partnerId]);
    fastForwardScript(); // End Night 1

    expect(gameEngine.deadPlayerIds, contains(partnerId));
    expect(gameEngine.deadPlayerIds, contains(clingerId));
  });

  test('Scenario 2: Medic Saves', () async {
    final medic = gameEngine.players.firstWhere((p) => p.role.id == 'medic');
    final victimId = idOfRole('party_animal');
    medic.medicChoice = 'PROTECT_DAILY';
    fastForwardScript();
    executeScriptStep('dealer', [victimId]);
    executeScriptStep('medic', [victimId]);
    fastForwardScript();
    expect(gameEngine.deadPlayerIds, isEmpty);
  });

  test('Scenario 5: Messy Bitch', () async {
    final p1Id = idOfRole('party_animal');
    final p2Id = idOfRole('minor');
    fastForwardScript();
    executeScriptStep('messy_bitch', [p1Id]);
    fastForwardScript(); // to day
    fastForwardScript(); // to night 2
    executeScriptStep('messy_bitch', [p2Id]);
    fastForwardScript();
  });
}
