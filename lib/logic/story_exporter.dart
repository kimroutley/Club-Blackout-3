import '../models/game_story_snapshot.dart';
import 'game_engine.dart';

GameStorySnapshot buildStorySnapshot(GameEngine engine) {
  final players = engine.guests.toList();

  return GameStorySnapshot(
    exportedAt: DateTime.now(),
    dayCount: engine.dayCount,
    phase: engine.currentPhase.name,
    players:
        players.map(StoryPlayerSnapshot.fromPlayer).toList(growable: false),
    gameLog: engine.gameLog.toList(growable: false),
    voteHistory: engine.voteHistory.toList(growable: false),
    currentDayVotesByVoter: Map<String, String?>.from(
      engine.currentDayVotesByVoter,
    ),
    reactionEventHistory: engine.reactionSystem.getHistoryJson(),
    nightHistory: List<Map<String, dynamic>>.from(engine.nightHistory),
    voteChanges: engine.voteChanges.toList(growable: false),
    winner: engine.winner,
  );
}

extension StorySnapshotConvenience on GameEngine {
  GameStorySnapshot exportStorySnapshot() => buildStorySnapshot(this);
}
