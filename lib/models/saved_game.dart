class SavedGame {
  final String id;
  final String name;
  final DateTime savedAt;
  final int dayCount;
  final int alivePlayers;
  final int totalPlayers;
  final String currentPhase;
  
  SavedGame({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.dayCount,
    required this.alivePlayers,
    required this.totalPlayers,
    required this.currentPhase,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'savedAt': savedAt.toIso8601String(),
    'dayCount': dayCount,
    'alivePlayers': alivePlayers,
    'totalPlayers': totalPlayers,
    'currentPhase': currentPhase,
  };
  
  factory SavedGame.fromJson(Map<String, dynamic> json) => SavedGame(
    id: json['id'] as String,
    name: json['name'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
    dayCount: json['dayCount'] as int,
    alivePlayers: json['alivePlayers'] as int,
    totalPlayers: json['totalPlayers'] as int,
    currentPhase: json['currentPhase'] as String,
  );
}
