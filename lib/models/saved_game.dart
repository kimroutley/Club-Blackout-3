class SavedGame {
  static const int currentSchemaVersion = 1;

  final String id;
  final String name;
  final DateTime savedAt;
  final int dayCount;
  final int alivePlayers;
  final int totalPlayers;
  final String currentPhase;

  /// Save metadata schema version (not the game rules version).
  final int schemaVersion;

  SavedGame({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.dayCount,
    required this.alivePlayers,
    required this.totalPlayers,
    required this.currentPhase,
    this.schemaVersion = currentSchemaVersion,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'savedAt': savedAt.toIso8601String(),
        'dayCount': dayCount,
        'alivePlayers': alivePlayers,
        'totalPlayers': totalPlayers,
        'currentPhase': currentPhase,
      };

  factory SavedGame.fromJson(Map<String, dynamic> json) {
    DateTime parseSavedAt() {
      final raw = json['savedAt'];
      if (raw is String) {
        return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      if (raw is int) {
        // Old/alternate formats: epoch millis.
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    int parseInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    final id = (json['id'] is String) ? (json['id'] as String) : '';
    final name = (json['name'] is String) ? (json['name'] as String) : 'Save';
    final phase = (json['currentPhase'] is String)
        ? (json['currentPhase'] as String)
        : 'unknown';

    return SavedGame(
      schemaVersion: parseInt(json['schemaVersion'], fallback: 0),
      id: id,
      name: name,
      savedAt: parseSavedAt(),
      dayCount: parseInt(json['dayCount']),
      alivePlayers: parseInt(json['alivePlayers']),
      totalPlayers: parseInt(json['totalPlayers']),
      currentPhase: phase,
    );
  }
}
