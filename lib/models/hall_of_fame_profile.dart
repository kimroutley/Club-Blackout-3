class HallOfFameProfile {
  final String id;
  final String name;
  final int totalGames;
  final int totalWins;
  // Breakdown of roles played (Role Name -> Count)
  final Map<String, int> roleStats;
  // Breakdown of "Shenanigan Awards" won (Award Title -> Count)
  final Map<String, int> awardStats;
  final DateTime lastPlayed;

  HallOfFameProfile({
    required this.id,
    required this.name,
    this.totalGames = 0,
    this.totalWins = 0,
    Map<String, int>? roleStats,
    Map<String, int>? awardStats,
    DateTime? lastPlayed,
  })  : roleStats = roleStats ?? {},
        awardStats = awardStats ?? {},
        lastPlayed = lastPlayed ?? DateTime.now();

  double get winRate => totalGames == 0 ? 0.0 : totalWins / totalGames;

  factory HallOfFameProfile.fromJson(Map<String, dynamic> json) {
    return HallOfFameProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      totalGames: (json['totalGames'] as num?)?.toInt() ?? 0,
      totalWins: (json['totalWins'] as num?)?.toInt() ?? 0,
      roleStats: (json['roleStats'] as Map?)?.cast<String, int>() ?? {},
      awardStats: (json['awardStats'] as Map?)?.cast<String, int>() ?? {},
      lastPlayed: DateTime.tryParse(json['lastPlayed'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'totalGames': totalGames,
        'totalWins': totalWins,
        'roleStats': roleStats,
        'awardStats': awardStats,
        'lastPlayed': lastPlayed.toIso8601String(),
      };

  HallOfFameProfile copyWith({
    String? name,
    int? totalGames,
    int? totalWins,
    Map<String, int>? roleStats,
    Map<String, int>? awardStats,
    DateTime? lastPlayed,
  }) {
    return HallOfFameProfile(
      id: id,
      name: name ?? this.name,
      totalGames: totalGames ?? this.totalGames,
      totalWins: totalWins ?? this.totalWins,
      roleStats: roleStats ?? this.roleStats,
      awardStats: awardStats ?? this.awardStats,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }
}
