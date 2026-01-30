import 'game_engine.dart';

class LiveGameStats {
  final int totalPlayers;
  final int aliveCount;
  final int deadCount;
  final Map<String, int> allianceCounts; // 'Dealer', 'Party', 'Neutral'
  final Map<String, int> roleCounts;
  final int dealerAliveCount;
  final int partyAliveCount;
  final int neutralAliveCount;

  // Computed percentages
  double get dealerPercentage =>
      aliveCount > 0 ? dealerAliveCount / aliveCount : 0.0;
  double get partyPercentage =>
      aliveCount > 0 ? partyAliveCount / aliveCount : 0.0;
  double get neutralPercentage =>
      aliveCount > 0 ? neutralAliveCount / aliveCount : 0.0;

  LiveGameStats({
    required this.totalPlayers,
    required this.aliveCount,
    required this.deadCount,
    required this.allianceCounts,
    required this.roleCounts,
    required this.dealerAliveCount,
    required this.partyAliveCount,
    required this.neutralAliveCount,
  });

  factory LiveGameStats.fromEngine(GameEngine engine) {
    // Host-only stats should reflect active guests in the game.
    // Using engine.players can include the Host or disabled players and skew counts.
    final players = engine.guests.where((p) => p.isEnabled).toList();
    final alivePlayers = players.where((p) => p.isAlive).toList();
    final deadPlayers = players.where((p) => !p.isAlive).toList();

    final allianceMap = <String, int>{'Dealer': 0, 'Party': 0, 'Neutral': 0};

    final roleMap = <String, int>{};

    int dealerAlive = 0;
    int partyAlive = 0;
    int neutralAlive = 0;

    for (var p in alivePlayers) {
      // Role ID count
      roleMap[p.role.id] = (roleMap[p.role.id] ?? 0) + 1;

      // Alliance Logic
      // Usually role.alliance, but check for conversions if GameEngine doesn't update the role object directly
      // Assuming Player object might have overrides, but usually we trust p.role.alliance
      // However, some roles might change alliance dynamically.
      // For now, we trust the mapped alliance string.

      final String allianceKey = _normalizeAlliance(p.role.alliance);
      allianceMap[allianceKey] = (allianceMap[allianceKey] ?? 0) + 1;

      if (allianceKey == 'Dealer') {
        dealerAlive++;
      } else if (allianceKey == 'Party') {
        partyAlive++;
      } else {
        neutralAlive++;
      }
    }

    // You might want dead stats too, but usually live stats focus on the living.

    return LiveGameStats(
      totalPlayers: players.length,
      aliveCount: alivePlayers.length,
      deadCount: deadPlayers.length,
      allianceCounts: allianceMap,
      roleCounts: roleMap,
      dealerAliveCount: dealerAlive,
      partyAliveCount: partyAlive,
      neutralAliveCount: neutralAlive,
    );
  }

  static String _normalizeAlliance(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('dealer')) return 'Dealer';
    if (lower.contains('party')) return 'Party';
    return 'Neutral';
  }
}
