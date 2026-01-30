import 'package:club_blackout/logic/ability_system.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/logic/reaction_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/file_role_repository.dart';

void main() {
  test('save/load persists in-flight engine state', () async {
    SharedPreferences.setMockInitialValues({});

    final roleRepo = FileRoleRepository();
    await roleRepo.loadRoles();

    final dealerRole = roleRepo.getRoleById('dealer');
    final dramaQueenRole = roleRepo.getRoleById('drama_queen');
    final predatorRole = roleRepo.getRoleById('predator');
    final teaSpillerRole = roleRepo.getRoleById('tea_spiller');

    expect(dealerRole, isNotNull);
    expect(dramaQueenRole, isNotNull);
    expect(predatorRole, isNotNull);
    expect(teaSpillerRole, isNotNull);

    final engine = GameEngine(roleRepository: roleRepo);

    engine.addPlayer('Alice', role: dealerRole);
    engine.addPlayer('Bob', role: dramaQueenRole);
    engine.addPlayer('Charlie', role: predatorRole);
    engine.addPlayer('Tina', role: teaSpillerRole);

    final aliceId = engine.players.firstWhere((p) => p.name == 'Alice').id;
    final bobId = engine.players.firstWhere((p) => p.name == 'Bob').id;
    final charlieId = engine.players.firstWhere((p) => p.name == 'Charlie').id;
    final tinaId = engine.players.firstWhere((p) => p.name == 'Tina').id;

    // In-flight night state
    engine.nightActions['kill'] = bobId;
    engine.deadPlayerIds.add(bobId);

    // In-flight votes
    engine.dayCount = 2;
    engine.setDayVote(voterId: aliceId, targetId: bobId);

    // Pending Predator retaliation state (voter eligible list)
    // Use Tina as the voter/mark target so the preferred target is eligible.
    engine.setDayVote(voterId: tinaId, targetId: charlieId);
    engine.nightActions['predator_mark'] = tinaId;
    engine.voteOutPlayer(charlieId);
    expect(engine.pendingPredatorId, charlieId);
    expect(engine.pendingPredatorEligibleVoterIds, contains(tinaId));
    expect(engine.pendingPredatorPreferredTargetId, tinaId);

    // Drama Queen pending state
    engine.dramaQueenSwapPending = true;
    engine.dramaQueenMarkedAId = aliceId;
    engine.dramaQueenMarkedBId = bobId;
    engine.lastDramaQueenSwap = const DramaQueenSwapRecord(
      day: 2,
      playerAName: 'Alice',
      playerBName: 'Bob',
      fromRoleA: 'dealer',
      fromRoleB: 'drama_queen',
      toRoleA: 'dealer',
      toRoleB: 'drama_queen',
    );

    // Status effects + history + ability queue
    engine.statusEffectManager.applyEffect(
      aliceId,
      CommonStatusEffects.createSilenced(duration: 1),
    );

    engine.reactionSystem.triggerEvent(
      GameEvent(type: GameEventType.gameStart, sourcePlayerId: aliceId),
      engine.players,
    );

    engine.abilityResolver.queueAbility(
      ActiveAbility(
        abilityId: 'test_kill',
        sourcePlayerId: aliceId,
        targetPlayerIds: [bobId],
        trigger: AbilityTrigger.nightAction,
        effect: AbilityEffect.kill,
        priority: 1,
        metadata: const {'roleName': 'Test'},
      ),
    );

    await engine.saveGame('test-save');

    final saves = await engine.getSavedGames();
    expect(saves, isNotEmpty);
    final saveId = saves.last.id;

    // Load into a fresh engine
    final engine2 = GameEngine(roleRepository: roleRepo);
    final loaded = await engine2.loadGame(saveId);
    expect(loaded, isTrue);

    expect(engine2.nightActions['kill'], bobId);
    expect(engine2.deadPlayerIds, contains(bobId));

    expect(engine2.currentDayVotesByVoter[aliceId], bobId);
    expect(engine2.voteHistory, isNotEmpty);

    expect(engine2.pendingPredatorId, charlieId);
    expect(engine2.pendingPredatorEligibleVoterIds, contains(tinaId));
    expect(engine2.pendingPredatorPreferredTargetId, tinaId);

    // Tea Spiller pending state
    engine.pendingTeaSpillerId = tinaId;
    engine.pendingTeaSpillerEligibleVoterIds = [aliceId, bobId];
    await engine.saveGame('test-save-2');
    final saves2 = await engine.getSavedGames();
    final saveId2 = saves2.last.id;
    final engine3 = GameEngine(roleRepository: roleRepo);
    final loaded2 = await engine3.loadGame(saveId2);
    expect(loaded2, isTrue);
    expect(engine3.hasPendingTeaSpillerReveal, isTrue);
    expect(engine3.pendingTeaSpillerId, tinaId);
    expect(engine3.pendingTeaSpillerEligibleVoterIds,
        containsAll([aliceId, bobId]));

    expect(engine2.dramaQueenSwapPending, isTrue);
    expect(engine2.dramaQueenMarkedAId, aliceId);
    expect(engine2.dramaQueenMarkedBId, bobId);
    expect(engine2.lastDramaQueenSwap, isNotNull);
    expect(engine2.lastDramaQueenSwap!.playerAName, 'Alice');

    expect(engine2.statusEffectManager.hasEffect(aliceId, 'silenced'), isTrue);
    expect(engine2.reactionSystem.getEventHistory(), isNotEmpty);

    final queueJson = engine2.abilityResolver.toJson();
    expect(queueJson['queue'], isA<List>());
    expect((queueJson['queue'] as List).length, 1);
  });
}
