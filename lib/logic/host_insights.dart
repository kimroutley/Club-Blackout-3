import '../models/game_log_entry.dart';
import '../models/script_step.dart';
import 'game_commentator.dart';
import 'game_dashboard_stats.dart';
import 'game_engine.dart';
import 'live_game_stats.dart';
import 'shenanigans_tracker.dart';
import 'voting_insights.dart';

/// Host-only derived data model.
///
/// This is the single place where the UI should source:
/// - live faction/role stats
/// - recent game events (log)
/// - last-night recap (host)
/// - active script step + progress
/// - fun commentary strings
/// - shenanigans awards
class HostInsightsSnapshot {
  /// Central dashboard stats (counts, voting, odds, chips).
  final GameDashboardStats dashboard;

  final LiveGameStats stats;
  final GamePhase phase;
  final int dayCount;

  final VotingInsights voting;
  final List<ShenaniganAward> shenanigans;  // Added

  /// Current script step (what the host should be reading/doing now).
  final ScriptStep? activeScriptStep;

  /// 0..1 progress through the current script queue.
  final double scriptProgress;

  /// Recent log entries (newest first).
  final List<GameLogEntry> recentEvents;

  /// Recent script entries (newest first).
  final List<GameLogEntry> recentScript;

  /// Host recap lines for last night (ready to render).
  final List<String> lastNightRecapLines;

  /// Quick numeric deltas for last night.
  final Map<String, int> lastNightStats;

  /// Short, host-facing flavor commentary.
  final String commentary;

  const HostInsightsSnapshot({
    required this.dashboard,
    required this.stats,
    required this.phase,
    required this.dayCount,
    required this.voting,
    required this.shenanigans, // Added
    required this.activeScriptStep,
    required this.scriptProgress,
    required this.recentEvents,
    required this.recentScript,
    required this.lastNightRecapLines,
    required this.lastNightStats,
    required this.commentary,
  });

  factory HostInsightsSnapshot.fromEngine(
    GameEngine engine, {
    int recentEventLimit = 20,
    int recentScriptLimit = 8,
  }) {
    final dashboard = GameDashboardStats.fromEngine(engine);
    final stats = dashboard.live;
    final voting = dashboard.voting;
    final shenanigans = ShenanigansTracker.generateAwards(engine); // Added

    final totalSteps = engine.scriptQueue.length;
    final idx = engine.currentScriptIndex;
    final progress =
        totalSteps <= 0 ? 0.0 : ((idx + 1) / totalSteps).clamp(0.0, 1.0);

    final allLogs = engine.gameLog;

    final recentEvents = allLogs
        .where((e) => e.type != GameLogType.script)
        .take(recentEventLimit)
        .toList();

    final recentScript = allLogs
        .where((e) => e.type == GameLogType.script)
        .take(recentScriptLimit)
        .toList();

    final recapLines = HostInsights.parseRecapLines(
      engine.lastNightHostRecap.isNotEmpty
          ? engine.lastNightHostRecap
          : engine.lastNightSummary,
    );

    final commentary =
        GameCommentator.generateCommentary(stats, engine.dayCount);

    return HostInsightsSnapshot(
      dashboard: dashboard,
      stats: stats,
      phase: engine.currentPhase,
      dayCount: engine.dayCount,
      voting: voting,
      shenanigans: shenanigans, // Added
      activeScriptStep: engine.currentScriptStep,
      scriptProgress: progress,
      recentEvents: recentEvents,
      recentScript: recentScript,
      lastNightRecapLines: recapLines,
      lastNightStats: Map<String, int>.from(engine.lastNightStats),
      commentary: commentary,
    );
  }
}

class HostInsights {
  /// Parses a recap block into render-ready lines.
  ///
  /// - Removes empty lines
  /// - Normalizes bullet formatting
  static List<String> parseRecapLines(String recap) {
    final trimmed = recap.trim();
    if (trimmed.isEmpty) return const [];

    return trimmed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map(_normalizeBulletLine)
        .toList();
  }

  static String _normalizeBulletLine(String line) {
    // Normalize common bullet patterns so the UI can apply its own bullet icon.
    if (line.startsWith('• ')) return line.substring(2).trimLeft();
    if (line.startsWith('- ')) return line.substring(2).trimLeft();
    return line;
  }
}
