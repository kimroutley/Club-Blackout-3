import '../models/player.dart';
import '../models/vote_cast.dart';
import 'game_engine.dart';

class VotingTargetBreakdown {
  final String targetId;
  final String targetName;
  final int voteCount;
  final List<String> voterIds;
  final List<String> voterNames;

  const VotingTargetBreakdown({
    required this.targetId,
    required this.targetName,
    required this.voteCount,
    required this.voterIds,
    required this.voterNames,
  });
}

class VotingVoterStat {
  final String voterId;
  final String voterName;
  final int voteActions;
  final int changes;

  const VotingVoterStat({
    required this.voterId,
    required this.voterName,
    required this.voteActions,
    required this.changes,
  });
}

/// Host-focused read model for voting.
///
/// This intentionally leans into "fun stats" rather than strict game rules.
class VotingInsights {
  final int day;

  /// How many players currently have a non-null vote.
  final int votesCastToday;

  /// Per-target breakdown of current votes (sorted desc by vote count).
  final List<VotingTargetBreakdown> currentBreakdown;

  /// Total count of vote actions recorded so far (over the whole game).
  final int totalVoteActions;

  /// Top "most active" voters (by vote actions), for commentary.
  final List<VotingVoterStat> topVoters;

  /// Most targeted players over time (based on vote actions towards them).
  final List<VotingTargetBreakdown> mostTargetedAllTime;

  const VotingInsights({
    required this.day,
    required this.votesCastToday,
    required this.currentBreakdown,
    required this.totalVoteActions,
    required this.topVoters,
    required this.mostTargetedAllTime,
  });

  factory VotingInsights.fromEngine(
    GameEngine engine, {
    int topVoterLimit = 3,
    int topTargetLimit = 3,
  }) {
    final playersById = <String, Player>{
      for (final p in engine.players) p.id: p,
    };

    // Current breakdown (uses current-day voter->target mapping).
    final breakdown = <VotingTargetBreakdown>[];
    final byTarget = engine.eligibleDayVotesByTarget;

    for (final entry in byTarget.entries) {
      final targetId = entry.key;
      final voterIds = List<String>.from(entry.value);
      final target = playersById[targetId];
      if (target == null) continue;

      voterIds.sort((a, b) {
        final an = playersById[a]?.name ?? '';
        final bn = playersById[b]?.name ?? '';
        return an.compareTo(bn);
      });

      final voterNames = voterIds
          .map((id) => playersById[id]?.name ?? id)
          .toList(growable: false);

      breakdown.add(
        VotingTargetBreakdown(
          targetId: targetId,
          targetName: target.name,
          voteCount: voterIds.length,
          voterIds: voterIds,
          voterNames: voterNames,
        ),
      );
    }

    breakdown.sort((a, b) => b.voteCount.compareTo(a.voteCount));

    // History stats.
    final history = engine.voteHistory;

    // Vote actions per voter, plus "changes" (target changes over time).
    final actionsByVoter = <String, int>{};
    final changesByVoter = <String, int>{};
    final lastTargetByVoter = <String, String?>{};

    final sortedHistory = List<VoteCast>.from(history)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    for (final v in sortedHistory) {
      // Only count explicit votes (ignore clears as an action for stats by default).
      if (v.targetId != null) {
        actionsByVoter[v.voterId] = (actionsByVoter[v.voterId] ?? 0) + 1;
      }

      final last = lastTargetByVoter[v.voterId];
      if (last != null && v.targetId != null && v.targetId != last) {
        changesByVoter[v.voterId] = (changesByVoter[v.voterId] ?? 0) + 1;
      }
      if (v.targetId != null) {
        lastTargetByVoter[v.voterId] = v.targetId;
      }
    }

    final topVoters = actionsByVoter.entries
        .map(
          (e) => VotingVoterStat(
            voterId: e.key,
            voterName: playersById[e.key]?.name ?? e.key,
            voteActions: e.value,
            changes: changesByVoter[e.key] ?? 0,
          ),
        )
        .toList();

    topVoters.sort((a, b) {
      final byActions = b.voteActions.compareTo(a.voteActions);
      if (byActions != 0) return byActions;
      return b.changes.compareTo(a.changes);
    });

    // Most targeted all-time: count vote actions that pointed at the target.
    final targetActions = <String, int>{};
    for (final v in history) {
      final t = v.targetId;
      if (t == null) continue;
      targetActions[t] = (targetActions[t] ?? 0) + 1;
    }

    final mostTargeted = targetActions.entries
        .map((e) {
          final target = playersById[e.key];
          if (target == null) return null;
          return VotingTargetBreakdown(
            targetId: e.key,
            targetName: target.name,
            voteCount: e.value,
            voterIds: const [],
            voterNames: const [],
          );
        })
        .whereType<VotingTargetBreakdown>()
        .toList();

    mostTargeted.sort((a, b) => b.voteCount.compareTo(a.voteCount));

    final votesCastToday = engine.currentDayVotesByVoter.entries
      .where((e) => e.value != null)
      .where((e) => !(playersById[e.key]?.soberSentHome ?? false))
      .length;

    return VotingInsights(
      day: engine.dayCount,
      votesCastToday: votesCastToday,
      currentBreakdown: breakdown,
      totalVoteActions: history.where((v) => v.targetId != null).length,
      topVoters: topVoters.take(topVoterLimit).toList(growable: false),
      mostTargetedAllTime:
          mostTargeted.take(topTargetLimit).toList(growable: false),
    );
  }
}
