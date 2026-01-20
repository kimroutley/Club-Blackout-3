enum GameLogType { script, action, system }

class GameLogEntry {
  final int turn;
  final String phase;
  final String title;
  final String description;
  final DateTime timestamp;
  final GameLogType type;

  GameLogEntry({
    required this.turn,
    required this.phase,
    required this.title,
    required this.description,
    required this.timestamp,
    this.type = GameLogType.action,
  });

  String get action => title;
  String get details => description;

  Map<String, dynamic> toJson() {
    return {
      'turn': turn,
      'phase': phase,
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString(),
    };
  }

  factory GameLogEntry.fromJson(Map<String, dynamic> json) {
    return GameLogEntry(
      turn: json['turn'] as int,
      phase: json['phase'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: json['type'] != null
          ? GameLogType.values.firstWhere(
              (e) => e.toString() == json['type'],
              orElse: () => GameLogType.action,
            )
          : GameLogType.action,
    );
  }
}
