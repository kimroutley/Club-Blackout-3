import 'game_log_entry.dart';
import 'player.dart';
import 'vote_cast.dart';

class StoryPlayerSnapshot {
  final String id;
  final String name;
  final String roleId;
  final String roleName;
  final String alliance;
  final bool isAlive;
  final bool isEnabled;

  const StoryPlayerSnapshot({
    required this.id,
    required this.name,
    required this.roleId,
    required this.roleName,
    required this.alliance,
    required this.isAlive,
    required this.isEnabled,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roleId': roleId,
        'roleName': roleName,
        'alliance': alliance,
        'isAlive': isAlive,
        'isEnabled': isEnabled,
      };

  factory StoryPlayerSnapshot.fromJson(Map<String, dynamic> json) {
    return StoryPlayerSnapshot(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      roleId: json['roleId'] as String? ?? '',
      roleName: json['roleName'] as String? ?? '',
      alliance: json['alliance'] as String? ?? '',
      isAlive: json['isAlive'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? false,
    );
  }

  factory StoryPlayerSnapshot.fromPlayer(Player p) => StoryPlayerSnapshot(
        id: p.id,
        name: p.name,
        roleId: p.role.id,
        roleName: p.role.name,
        alliance: p.alliance,
        isAlive: p.isAlive,
        isEnabled: p.isEnabled,
      );
}

/// A single exportable snapshot of gameplay data.
///
/// Goal: make it easy to feed into an AI narrator without the narrator needing
/// to know internal engine structures.
class GameStorySnapshot {
  final DateTime exportedAt;
  final int dayCount;
  final String phase;

  final List<StoryPlayerSnapshot> players;

  /// Host-readable log. Contains actions + system events already curated.
  final List<GameLogEntry> gameLog;

  /// Raw vote history (timestamped vote changes).
  final List<VoteCast> voteHistory;

  /// Current vote state (who is voting for who right now).
  final Map<String, String?> currentDayVotesByVoter;

  /// Reaction system event history (useful for cause/effect narration).
  final List<Map<String, dynamic>> reactionEventHistory;

  /// Full night action history (for complex stats).
  final List<Map<String, dynamic>> nightHistory;

  /// Vote flip-flop history (intermediate votes).
  final List<VoteCast> voteChanges;

  final String? winner;

  const GameStorySnapshot({
    required this.exportedAt,
    required this.dayCount,
    required this.phase,
    required this.players,
    required this.gameLog,
    required this.voteHistory,
    required this.currentDayVotesByVoter,
    required this.reactionEventHistory,
    required this.nightHistory,
    required this.voteChanges,
    this.winner,
  });

  factory GameStorySnapshot.fromJson(Map<String, dynamic> json) {
    final playersJson = (json['players'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);

    final logJson = (json['gameLog'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);

    final voteJson = (json['voteHistory'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);

    final reactions =
        (json['reactionEventHistory'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false);

    final nights = (json['nightHistory'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);

    final changesJson = (json['voteChanges'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);

    final votesByVoter =
        (json['currentDayVotesByVoter'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    return GameStorySnapshot(
      exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      dayCount: (json['dayCount'] as num?)?.toInt() ?? 0,
      phase: json['phase'] as String? ?? '',
      players: playersJson
          .map((p) => StoryPlayerSnapshot.fromJson(p))
          .toList(growable: false),
      gameLog:
          logJson.map((e) => GameLogEntry.fromJson(e)).toList(growable: false),
      voteHistory:
          voteJson.map((e) => VoteCast.fromJson(e)).toList(growable: false),
      currentDayVotesByVoter: votesByVoter.map(
        (k, v) => MapEntry(k, v is String ? v : null),
      ),
      reactionEventHistory: reactions,
      nightHistory: nights,
      voteChanges:
          changesJson.map((e) => VoteCast.fromJson(e)).toList(growable: false),
      winner: json['winner'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'exportedAt': exportedAt.toIso8601String(),
        'dayCount': dayCount,
        'phase': phase,
        'players': players.map((p) => p.toJson()).toList(),
        'gameLog': gameLog.map((e) => e.toJson()).toList(),
        'voteHistory': voteHistory.map((v) => v.toJson()).toList(),
        'currentDayVotesByVoter': currentDayVotesByVoter,
        'reactionEventHistory': reactionEventHistory,
        'nightHistory': nightHistory,
        'voteChanges': voteChanges.map((v) => v.toJson()).toList(),
        'winner': winner,
      };
}
