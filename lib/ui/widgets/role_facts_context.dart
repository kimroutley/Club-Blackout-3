import '../../models/role.dart';

/// Lightweight, UI-only context for generating dynamic "fun facts" on role cards.
///
/// These are intentionally *heuristics* (not authoritative probabilities).
class RoleFactsContext {
  final int totalPlayers;
  final int alivePlayers;

  /// Count of alive roles that perform the core night kill.
  ///
  /// Today this means roles with id == 'dealer'.
  final int dealerKillersAlive;

  /// 1 = most likely to die (highest danger score).
  final Map<String, int> dangerRankByRoleId;

  /// Number of ranked roles.
  final int dangerRankCount;

  const RoleFactsContext({
    required this.totalPlayers,
    required this.alivePlayers,
    required this.dealerKillersAlive,
    required this.dangerRankByRoleId,
    required this.dangerRankCount,
  });

  int? dangerRankFor(Role role) => dangerRankByRoleId[role.id];

  /// 0.0 = safest in lobby, 1.0 = most likely to die.
  double? dangerPercentileFor(Role role) {
    final rank = dangerRankFor(role);
    if (rank == null) return null;
    if (dangerRankCount <= 1) return 0.0;
    // rank=1 (most dangerous) -> 1.0
    return (dangerRankCount - rank) / (dangerRankCount - 1);
  }

  static RoleFactsContext fromRoster({
    required List<Role> rosterRoles,
    required int totalPlayers,
    required int alivePlayers,
    required int dealerKillersAlive,
  }) {
    // Rank unique role ids (but keep deterministic ordering for ties).
    final byId = <String, Role>{};
    for (final r in rosterRoles) {
      byId.putIfAbsent(r.id, () => r);
    }

    final roles = byId.values.toList(growable: false);

    final scores = <String, double>{};
    for (final r in roles) {
      scores[r.id] = _dangerScore(
        r,
        totalPlayers: totalPlayers,
        alivePlayers: alivePlayers,
        dealerKillersAlive: dealerKillersAlive,
      );
    }

    roles.sort((a, b) {
      final sa = scores[a.id] ?? 0.0;
      final sb = scores[b.id] ?? 0.0;
      final byScore = sb.compareTo(sa); // desc
      if (byScore != 0) return byScore;
      return a.name.compareTo(b.name);
    });

    final dangerRankByRoleId = <String, int>{};
    for (var i = 0; i < roles.length; i++) {
      dangerRankByRoleId[roles[i].id] = i + 1;
    }

    return RoleFactsContext(
      totalPlayers: totalPlayers,
      alivePlayers: alivePlayers,
      dealerKillersAlive: dealerKillersAlive,
      dangerRankByRoleId: dangerRankByRoleId,
      dangerRankCount: roles.length,
    );
  }

  static double _dangerScore(
    Role role, {
    required int totalPlayers,
    required int alivePlayers,
    required int dealerKillersAlive,
  }) {
    // Base score: roughly corresponds to Low/Medium/High vibes.
    var base = switch (role.id) {
      'ally_cat' => 0.35,
      'seasoned_drinker' => 0.42,
      'second_wind' => 0.55,
      'party_animal' => 0.58,
      'sober' => 0.60,
      'club_manager' => 0.64,
      'drama_queen' => 0.66,
      'silver_fox' => 0.64,
      'bartender' => 0.66,
      'clinger' => 0.62,
      'creep' => 0.62,
      'dealer' => 0.74,
      'whore' => 0.76,
      'roofi' => 0.78,
      'bouncer' => 0.80,
      'medic' => 0.82,
      'wallflower' => 0.84,
      'tea_spiller' => 0.78,
      'minor' => 0.72,
      'messy_bitch' => 0.70,
      'predator' => 0.72,
      'lightweight' => 0.68,
      'host' => 0.0,
      _ => 0.62,
    };

    // Role "type" influences targeting pressure (investigators/protectors get hunted).
    final t = role.type.trim().toLowerCase();
    base += switch (t) {
      'investigative' => 0.08,
      'defensive' => 0.06,
      'aggressive' => 0.04,
      'chaos' => 0.03,
      'passive' => -0.02,
      _ => 0.0,
    };

    // Night position: roles that act during key phases tend to draw suspicion.
    if (role.nightPriority >= 5) base += 0.05;
    if (role.nightPriority <= 0) base -= 0.02;

    // More killers increases overall pressure slightly.
    if (dealerKillersAlive > 1) {
      base += 0.02 * (dealerKillersAlive - 1);
    }

    // Bigger lobbies slightly dilute per-night elimination risk.
    // Keep this subtle so the rank remains intuitive.
    if (totalPlayers >= 10) base -= 0.01;
    if (totalPlayers >= 14) base -= 0.01;

    // Clamp.
    if (base < 0.0) base = 0.0;
    if (base > 1.0) base = 1.0;

    // Avoid unused warning.
    // (alivePlayers is here for future refinements; keep signature stable.)
    // ignore: unused_local_variable
    final _ = alivePlayers;

    return base;
  }
}
