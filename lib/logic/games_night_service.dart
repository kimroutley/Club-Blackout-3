import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_log_entry.dart';
import '../models/game_story_snapshot.dart';
import '../models/vote_cast.dart';
import 'game_engine.dart';
import 'hall_of_fame_service.dart';
import 'shenanigans_tracker.dart';
import 'story_exporter.dart';

class GamesNightTopNameStat {
  final String name;
  final int count;

  const GamesNightTopNameStat({required this.name, required this.count});
}

class GamesNightVoterStat {
  final String voterName;
  final int voteActions;
  final int changes;

  const GamesNightVoterStat({
    required this.voterName,
    required this.voteActions,
    required this.changes,
  });
}

class GamesNightVotingInsights {
  final int totalVoteActions;
  final List<GamesNightVoterStat> topVoters;
  final List<GamesNightTopNameStat> mostTargeted;

  const GamesNightVotingInsights({
    required this.totalVoteActions,
    required this.topVoters,
    required this.mostTargeted,
  });
}

class GamesNightActionInsights {
  final int totalLogEntries;
  final Map<GameLogType, int> byType;
  final List<GamesNightTopNameStat> topTitles;

  const GamesNightActionInsights({
    required this.totalLogEntries,
    required this.byType,
    required this.topTitles,
  });
}

class GamesNightInsights {
  final bool isActive;
  final DateTime? startedAt;
  final int gamesRecorded;
  final GamesNightVotingInsights voting;
  final GamesNightActionInsights actions;
  final Map<String, int> roles;

  const GamesNightInsights({
    required this.isActive,
    required this.startedAt,
    required this.gamesRecorded,
    required this.voting,
    required this.actions,
    required this.roles,
  });
}

class _GamesNightGameRecord {
  final DateTime startedAt;
  final GameStorySnapshot startSnapshot;
  GameStorySnapshot? endSnapshot;
  String? winner;
  String? winMessage;
  DateTime? endedAt;

  _GamesNightGameRecord({
    required this.startedAt,
    required this.startSnapshot,
  });

  factory _GamesNightGameRecord.fromJson(Map<String, dynamic> json) {
    final startSnapJson =
        (json['startSnapshot'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final endSnapJson =
        (json['endSnapshot'] as Map?)?.cast<String, dynamic>();

    return _GamesNightGameRecord(
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startSnapshot: GameStorySnapshot.fromJson(startSnapJson),
    )
      ..endedAt = DateTime.tryParse(json['endedAt'] as String? ?? '')
      ..winner = json['winner'] as String?
      ..winMessage = json['winMessage'] as String?
      ..endSnapshot =
          endSnapJson == null ? null : GameStorySnapshot.fromJson(endSnapJson);
  }

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'winner': winner,
        'winMessage': winMessage,
        'startSnapshot': startSnapshot.toJson(),
        'endSnapshot': endSnapshot?.toJson(),
      };
}

class _GamesNightEventRecord {
  final int gameIndex;
  final GameLogEntry entry;

  const _GamesNightEventRecord({required this.gameIndex, required this.entry});

  factory _GamesNightEventRecord.fromJson(Map<String, dynamic> json) {
    final entryJson = (json['entry'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return _GamesNightEventRecord(
      gameIndex: (json['gameIndex'] as num?)?.toInt() ?? 0,
      entry: GameLogEntry.fromJson(entryJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'gameIndex': gameIndex,
        'entry': entry.toJson(),
      };
}

/// Records gameplay across multiple games during a real-world "Games Night".
///
/// - When inactive: no recording.
/// - When active: records every log action + a snapshot at game start/end.
///
/// This intentionally lives outside [GameEngine] so it survives NEW GAME
/// engine recreation.
class GamesNightService extends ChangeNotifier {
  static final GamesNightService instance = GamesNightService._();

  GamesNightService._();

  static const String _prefsKey = 'gamesNight.session.v1';
  static const int _persistVersion = 1;

  Timer? _saveDebounce;

  bool _isActive = false;
  DateTime? _startedAt;

  int _currentGameIndex = -1;
  final List<_GamesNightGameRecord> _games = <_GamesNightGameRecord>[];
  final List<_GamesNightEventRecord> _events = <_GamesNightEventRecord>[];

  /// Public accessor for completed game snapshots (useful for Shenanigans stats)
  List<GameStorySnapshot> get completedGameSnapshots => _games
      .map((g) => g.endSnapshot)
      .whereType<GameStorySnapshot>()
      .toList();

  bool get isActive => _isActive;
  DateTime? get startedAt => _startedAt;
  DateTime? get sessionStartTime => _startedAt;

  int get gamesRecorded => _games.length;
  int get gamesRecordedCount => _games.length;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final data = decoded.cast<String, dynamic>();

      final version = (data['version'] as num?)?.toInt() ?? 0;
      if (version != _persistVersion) {
        // If schema changes later, we can migrate here.
      }

      _isActive = data['isActive'] as bool? ?? false;
      _startedAt = DateTime.tryParse(data['startedAt'] as String? ?? '');
      _currentGameIndex = (data['currentGameIndex'] as num?)?.toInt() ?? -1;

      final gamesJson = (data['games'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);

      final eventsJson = (data['events'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);

      _games
        ..clear()
        ..addAll(gamesJson.map(_GamesNightGameRecord.fromJson));

      _events
        ..clear()
        ..addAll(eventsJson.map(_GamesNightEventRecord.fromJson));

      if (_games.isEmpty) {
        _currentGameIndex = -1;
      } else {
        _currentGameIndex = _currentGameIndex.clamp(0, _games.length - 1);
      }

      // If the session was active but missing a start time, set one.
      _startedAt ??= _isActive ? DateTime.now() : null;

      notifyListeners();
    } catch (_) {
      // Corrupt payload: clear it to avoid trapping users in a crash loop.
      await prefs.remove(_prefsKey);
      _isActive = false;
      _startedAt = null;
      _currentGameIndex = -1;
      _games.clear();
      _events.clear();
      notifyListeners();
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(_toPersistedJson()));
      } catch (_) {
        // Swallow persistence errors: gameplay must never fail due to stats.
      }
    });
  }

  Map<String, dynamic> _toPersistedJson() => {
        'version': _persistVersion,
        'isActive': _isActive,
        'startedAt': _startedAt?.toIso8601String(),
        'currentGameIndex': _currentGameIndex,
        'games': _games.map((g) => g.toJson()).toList(growable: false),
        'events': _events.map((e) => e.toJson()).toList(growable: false),
      };

  void start() {
    if (_isActive) return;
    _isActive = true;
    _startedAt = DateTime.now();
    notifyListeners();
    _scheduleSave();
  }

  void startSession() => start();

  void stop() {
    if (!_isActive) return;
    _isActive = false;
    notifyListeners();
    _scheduleSave();
  }

  void endSession() => stop();

  void clear() {
    _currentGameIndex = -1;
    _games.clear();
    _events.clear();
    notifyListeners();
    _scheduleSave();
  }

  void recordGameStarted(GameEngine engine) {
    if (!_isActive) return;

    _currentGameIndex++;
    _games.add(
      _GamesNightGameRecord(
        startedAt: DateTime.now(),
        startSnapshot: engine.exportStorySnapshot(),
      ),
    );

    notifyListeners();
    _scheduleSave();
  }

  void recordGameEnded(GameEngine engine) {
    // ALWAYS update Hall of Fame (Global Stats)
    // We snapshot immediately to capture accurate state
    final snapshot = engine.exportStorySnapshot();
    try {
      final awards = ShenanigansTracker.generateAwards(engine);
      HallOfFameService.instance.processGameStats(snapshot, awards);
    } catch (e) {
      debugPrint('Failed to update Hall of Fame: $e');
    }

    // Only record in the current "Games Night" session if active
    if (!_isActive) return;

    if (_currentGameIndex < 0) {
      // Defensive: if we somehow missed the game start, create one now.
      recordGameStarted(engine);
    }

    final idx = _currentGameIndex.clamp(0, _games.length - 1);
    final rec = _games[idx];

    rec.endedAt ??= DateTime.now();
    rec.winner ??= engine.winner;
    rec.winMessage ??= engine.winMessage;
    // rec.endSnapshot might be redundant if we just created one, but keep logic simple
    rec.endSnapshot ??= snapshot;

    notifyListeners();
    _scheduleSave();
  }

  void recordLogEntry(GameLogEntry entry) {
    if (!_isActive) return;

    if (_currentGameIndex < 0) {
      // Log happened before we saw a formal game start.
      _currentGameIndex = 0;
    }

    _events.add(
      _GamesNightEventRecord(gameIndex: _currentGameIndex, entry: entry),
    );

    // Keep this lightweight: UI will rebuild anyway.
    notifyListeners();
    _scheduleSave();
  }

  GamesNightInsights buildInsights({
    int topVoterLimit = 5,
    int topTargetLimit = 5,
    int topTitleLimit = 6,
  }) {
    final byType = <GameLogType, int>{};
    final titleCounts = <String, int>{};

    for (final e in _events) {
      byType[e.entry.type] = (byType[e.entry.type] ?? 0) + 1;
      titleCounts[e.entry.title] = (titleCounts[e.entry.title] ?? 0) + 1;
    }

    final topTitles = titleCounts.entries
        .map((e) => GamesNightTopNameStat(name: e.key, count: e.value))
        .toList(growable: false)
      ..sort((a, b) => b.count.compareTo(a.count));

    // Votes and roles are computed from snapshots so they don't depend on log text.
    final voterActionsByName = <String, int>{};
    final voterChangesByName = <String, int>{};
    final lastTargetByVoterName = <String, String?>{};

    final targetActionsByName = <String, int>{};

    int totalVoteActions = 0;
    final roles = <String, int>{};

    for (final game in _games) {
      final snap = game.endSnapshot ?? game.startSnapshot;

      final idToName = <String, String>{
        for (final p in snap.players) p.id: p.name,
      };
      final idToRole = <String, String>{
        for (final p in snap.players) p.id: p.roleName,
      };

      // Role distribution (enabled players only).
      for (final p in snap.players.where((p) => p.isEnabled)) {
        roles[p.roleName] = (roles[p.roleName] ?? 0) + 1;
      }

      // Count vote actions and changes.
      final sortedHistory = List<VoteCast>.from(snap.voteHistory)
        ..sort((a, b) => a.sequence.compareTo(b.sequence));

      for (final v in sortedHistory) {
        final targetId = v.targetId;
        if (targetId == null) continue;

        totalVoteActions++;

        final voterName = idToName[v.voterId] ?? v.voterId;
        voterActionsByName[voterName] = (voterActionsByName[voterName] ?? 0) + 1;

        final lastTarget = lastTargetByVoterName[voterName];
        if (lastTarget != null && lastTarget != targetId) {
          voterChangesByName[voterName] = (voterChangesByName[voterName] ?? 0) + 1;
        }
        lastTargetByVoterName[voterName] = targetId;

        final targetName = idToName[targetId] ?? idToRole[targetId] ?? targetId;
        targetActionsByName[targetName] = (targetActionsByName[targetName] ?? 0) + 1;
      }
    }

    final topVoters = voterActionsByName.entries
        .map(
          (e) => GamesNightVoterStat(
            voterName: e.key,
            voteActions: e.value,
            changes: voterChangesByName[e.key] ?? 0,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) {
        final byActions = b.voteActions.compareTo(a.voteActions);
        if (byActions != 0) return byActions;
        return b.changes.compareTo(a.changes);
      });

    final mostTargeted = targetActionsByName.entries
        .map((e) => GamesNightTopNameStat(name: e.key, count: e.value))
        .toList(growable: false)
      ..sort((a, b) => b.count.compareTo(a.count));

    final sortedRoles = roles.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final roleMap = <String, int>{for (final e in sortedRoles) e.key: e.value};

    return GamesNightInsights(
      isActive: _isActive,
      startedAt: _startedAt,
      gamesRecorded: _games.length,
      voting: GamesNightVotingInsights(
        totalVoteActions: totalVoteActions,
        topVoters: topVoters.take(topVoterLimit).toList(growable: false),
        mostTargeted:
            mostTargeted.take(topTargetLimit).toList(growable: false),
      ),
      actions: GamesNightActionInsights(
        totalLogEntries: _events.length,
        byType: Map<GameLogType, int>.from(byType),
        topTitles: topTitles.take(topTitleLimit).toList(growable: false),
      ),
      roles: roleMap,
    );
  }

  GamesNightInsights getInsights() => buildInsights();

  String exportSessionJson({bool pretty = true}) {
    final payload = {
      ..._toPersistedJson(),
      'gamesRecorded': _games.length,
      'insights': _insightsToJson(buildInsights()),
    };

    if (!pretty) return jsonEncode(payload);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Map<String, dynamic> toJson() => _toPersistedJson();

  Map<String, dynamic> _insightsToJson(GamesNightInsights i) => {
        'isActive': i.isActive,
        'startedAt': i.startedAt?.toIso8601String(),
        'gamesRecorded': i.gamesRecorded,
        'voting': {
          'totalVoteActions': i.voting.totalVoteActions,
          'topVoters': i.voting.topVoters
              .map((v) => {
                    'voterName': v.voterName,
                    'voteActions': v.voteActions,
                    'changes': v.changes,
                  })
              .toList(growable: false),
          'mostTargeted': i.voting.mostTargeted
              .map((t) => {'name': t.name, 'count': t.count})
              .toList(growable: false),
        },
        'actions': {
          'totalLogEntries': i.actions.totalLogEntries,
          'byType': {
            for (final e in i.actions.byType.entries)
              e.key.name: e.value,
          },
          'topTitles': i.actions.topTitles
              .map((t) => {'title': t.name, 'count': t.count})
              .toList(growable: false),
        },
        'roles': i.roles,
      };
}
