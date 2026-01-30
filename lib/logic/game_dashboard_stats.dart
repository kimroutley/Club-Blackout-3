import 'package:flutter/material.dart';

import '../models/game_log_entry.dart';
import '../models/role.dart';
import 'game_engine.dart';
import 'game_odds.dart';
import 'live_game_stats.dart';
import 'voting_insights.dart';

@immutable
class RoleChipStat {
  final String roleId;
  final String roleName;
  final Color color;
  final int aliveCount;

  const RoleChipStat({
    required this.roleId,
    required this.roleName,
    required this.color,
    required this.aliveCount,
  });
}

/// Central, host-facing dashboard read model.
///
/// Goal: one place to compute/format the "live" numbers the host UI shows.
/// This is derived from GameEngine state and updates in real time because the
/// host UI listens to the engine.
@immutable
class GameDashboardStats {
  final LiveGameStats live;
  final VotingInsights voting;
  final GameOddsSnapshot odds;

  /// Role chips are derived from alive, enabled players.
  final List<RoleChipStat> roleChips;

  /// Convenience: last non-script log entry.
  final GameLogEntry? lastEvent;

  const GameDashboardStats({
    required this.live,
    required this.voting,
    required this.odds,
    required this.roleChips,
    required this.lastEvent,
  });

  factory GameDashboardStats.fromEngine(
    GameEngine engine, {
    int roleChipLimit = 14,
  }) {
    final live = LiveGameStats.fromEngine(engine);
    final voting = VotingInsights.fromEngine(engine);
    final odds = GameOddsSnapshot.fromEngine(engine);

    final roleCounts = Map<String, int>.from(live.roleCounts);

    final chips = roleCounts.entries.map((e) {
      final Role? role = engine.roleRepository.getRoleById(e.key);
      final roleName = role?.name ?? e.key;
      final color = role?.color ?? Colors.grey;
      return RoleChipStat(
        roleId: e.key,
        roleName: roleName,
        color: color,
        aliveCount: e.value,
      );
    }).toList();

    chips.sort((a, b) {
      final byCount = b.aliveCount.compareTo(a.aliveCount);
      if (byCount != 0) return byCount;
      return a.roleName.compareTo(b.roleName);
    });

    GameLogEntry? lastEvent;
    for (final e in engine.gameLog) {
      if (e.type == GameLogType.script) continue;
      lastEvent = e;
      break;
    }

    return GameDashboardStats(
      live: live,
      voting: voting,
      odds: odds,
      roleChips: chips.take(roleChipLimit).toList(growable: false),
      lastEvent: lastEvent,
    );
  }
}
