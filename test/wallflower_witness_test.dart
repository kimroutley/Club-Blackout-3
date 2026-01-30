import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/script_step.dart';
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
    await gameEngine.createTestGame(fullRoster: true);
    await gameEngine.startGame();
  });

  void fastForwardPhaseChange() {
    int safety = 0;
    final initialPhase = gameEngine.currentPhase;
    final initialDay = gameEngine.dayCount;

    while (gameEngine.currentScriptIndex < gameEngine.scriptQueue.length &&
        safety < 600) {
      gameEngine.advanceScript();
      safety++;
      if (gameEngine.currentPhase != initialPhase ||
          gameEngine.dayCount != initialDay) {
        return;
      }
    }
    throw StateError('Failed to reach next phase change.');
  }

  void executeStepById(String stepId, List<String> selections) {
    int safety = 0;
    while (gameEngine.currentScriptIndex < gameEngine.scriptQueue.length &&
        safety < 600) {
      final step = gameEngine.scriptQueue[gameEngine.currentScriptIndex];
      if (step.id == stepId) {
        if (step.actionType == ScriptActionType.toggleOption) {
          gameEngine.handleScriptOption(step, selections.first);
        } else {
          gameEngine.handleScriptAction(step, selections);
        }
        gameEngine.advanceScript();
        return;
      }
      gameEngine.advanceScript();
      safety++;
    }
    throw StateError('Step $stepId not found in script queue.');
  }

  test('Wallflower can skip witnessing (queues skip, not witness)', () async {
    // Advance: Setup night -> Night 1.
    fastForwardPhaseChange();
    expect(gameEngine.currentPhase, GamePhase.night);
    expect(gameEngine.dayCount, 1);

    // Dealers pick a victim so there is something to witness.
    final victimId =
        gameEngine.players.firstWhere((p) => p.role.id == 'party_animal').id;
    executeStepById('dealer_act', [victimId]);

    // Wallflower explicitly declines to witness.
    final wallflowerStep =
        gameEngine.scriptQueue.skip(gameEngine.currentScriptIndex).firstWhere(
              (s) => s.id == 'wallflower_act',
              orElse: () => const ScriptStep(
                id: 'missing',
                title: 'missing',
                readAloudText: '',
                instructionText: '',
                actionType: ScriptActionType.none,
              ),
            );
    expect(wallflowerStep.id, 'wallflower_act');

    executeStepById('wallflower_act', ['SKIP']);

    final queueJson = gameEngine.abilityResolver.toJson();
    final queue = (queueJson['queue'] as List).cast<Map<String, dynamic>>();

    expect(queue.any((a) => a['abilityId'] == 'wallflower_witness'), isFalse);
    expect(queue.any((a) => a['abilityId'] == 'wallflower_skip'), isTrue);
  });

  test('Wallflower witness mode is logged (peek) and appears in morning report',
      () async {
    // Advance: Setup night -> Night 1.
    fastForwardPhaseChange();
    expect(gameEngine.currentPhase, GamePhase.night);
    expect(gameEngine.dayCount, 1);

    // Dealers pick a victim so there is something to witness.
    final victimId =
        gameEngine.players.firstWhere((p) => p.role.id == 'party_animal').id;
    executeStepById('dealer_act', [victimId]);

    executeStepById('wallflower_act', ['PEEK']);

    // Resolve the rest of the night to day (builds the morning report).
    fastForwardPhaseChange();

    expect(gameEngine.lastNightSummary.toLowerCase(), contains('peeked'));
    expect(gameEngine.lastNightHostRecap.toLowerCase(), contains('wallflower'));
    expect(gameEngine.lastNightHostRecap.toLowerCase(), contains('peeked'));

    // Ensure it's preserved for story export (via gameLog entries).
    expect(
      gameEngine.gameLog
          .any((e) => e.description.toLowerCase().contains('wallflower chose to peek')),
      isTrue,
    );
  });

  test('Wallflower witness mode can be logged as stare', () async {
    fastForwardPhaseChange();
    expect(gameEngine.currentPhase, GamePhase.night);
    expect(gameEngine.dayCount, 1);

    final victimId =
        gameEngine.players.firstWhere((p) => p.role.id == 'party_animal').id;
    executeStepById('dealer_act', [victimId]);

    executeStepById('wallflower_act', ['STARE']);
    fastForwardPhaseChange();

    expect(gameEngine.lastNightSummary.toLowerCase(), contains('stared'));
    expect(
      gameEngine.gameLog
          .any((e) => e.description.toLowerCase().contains('wallflower chose to stare')),
      isTrue,
    );
  });

  test('Sober sending Wallflower home removes witness step', () async {
    // Advance: Setup night -> Night 1.
    fastForwardPhaseChange();
    expect(gameEngine.currentPhase, GamePhase.night);
    expect(gameEngine.dayCount, 1);

    final wallflowerId =
        gameEngine.players.firstWhere((p) => p.role.id == 'wallflower').id;

    // Sober sends Wallflower home, which rebuilds the remaining night script.
    executeStepById('sober_act', [wallflowerId]);

    final remainingSteps =
        gameEngine.scriptQueue.skip(gameEngine.currentScriptIndex).toList();
    expect(remainingSteps.any((s) => s.id == 'wallflower_act'), isFalse);
  });
}
