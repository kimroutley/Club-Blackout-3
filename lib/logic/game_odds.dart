import 'package:flutter/foundation.dart';

import '../models/player.dart';
import 'game_engine.dart';
import 'live_game_stats.dart';

@immutable
class GameOddsSnapshot {
  /// Winner token -> probability (0..1). Tokens match GameEndResult.winner
  /// (e.g. DEALER, PARTY_ANIMAL, CLUB_MANAGER, MESSY_BITCH).
  final Map<String, double> odds;

  /// Human-readable explanation of what the odds represent.
  final String note;

  const GameOddsSnapshot({required this.odds, required this.note});

  List<MapEntry<String, double>> get sortedDesc {
    final items = odds.entries.toList();
    items.sort((a, b) => b.value.compareTo(a.value));
    return items;
  }

  static GameOddsSnapshot fromEngine(GameEngine engine) {
    final end = engine.checkGameEnd();
    if (end != null) {
      return GameOddsSnapshot(
        odds: {end.winner: 1.0},
        note: 'Game is already over.',
      );
    }

    final live = LiveGameStats.fromEngine(engine);
    final enabled = engine.guests.where((p) => p.isEnabled).toList();
    final aliveEnabled = enabled.where((p) => p.isAlive).toList();

    if (aliveEnabled.isEmpty) {
      return const GameOddsSnapshot(
        odds: {'NONE': 1.0},
        note: 'No alive players.',
      );
    }

    // Heuristic, host-facing odds.
    // These are NOT a solver; they’re a lightweight “who seems ahead” meter.
    final aliveCount = live.aliveCount;
    final dealers = live.dealerAliveCount;
    final party = live.partyAliveCount;

    final messyAlive = aliveEnabled.any((p) => p.role.id == 'messy_bitch');
    final clubManagerAlive = aliveEnabled.any((p) => p.role.id == 'club_manager');

    final rumourCoverage = _rumourCoverage(enabled);

    double dealerScore = dealers.toDouble();
    double partyScore = party.toDouble();

    // Dealers only win at 1v1 per rules. If they’re far from that, down-weight.
    if (aliveCount > 2) {
      dealerScore *= 0.65;
    }

    // Party Animals’ condition is “all dealers dead”; they generally scale with numbers.
    partyScore *= 1.0;

    // Messy Bitch odds are tied to rumour spread progress.
    double messyScore = 0.0;
    if (messyAlive) {
      // Start small, ramp up quickly as rumours approach completion.
      messyScore = 0.25 + 1.75 * rumourCoverage;
    }

    // Club Manager can steal the endgame if final 2 are CM + Dealer.
    double clubManagerScore = 0.0;
    if (clubManagerAlive && dealers > 0) {
      clubManagerScore = 0.35;
      if (aliveCount <= 4) clubManagerScore += 0.35;
    }

    // If Dealers are currently at the exact 1v1 state, their odds spike.
    if (_isDealerOneVOne(engine.players)) {
      dealerScore += 5.0;
    }

    final scores = <String, double>{
      'DEALER': dealerScore,
      'PARTY_ANIMAL': partyScore,
      if (messyScore > 0) 'MESSY_BITCH': messyScore,
      if (clubManagerScore > 0) 'CLUB_MANAGER': clubManagerScore,
    };

    final total = scores.values.fold<double>(0.0, (a, b) => a + b);
    if (total <= 0) {
      return const GameOddsSnapshot(
        odds: {'PARTY_ANIMAL': 0.5, 'DEALER': 0.5},
        note: 'Insufficient data for odds.',
      );
    }

    final normalized = <String, double>{
      for (final e in scores.entries) e.key: (e.value / total).clamp(0.0, 1.0),
    };

    return GameOddsSnapshot(
      odds: normalized,
      note: 'Heuristic odds (not a strict rules solver).',
    );
  }

  static double _rumourCoverage(List<Player> enabledPlayers) {
    final eligible = enabledPlayers.where((p) => p.isEnabled).toList();
    if (eligible.isEmpty) return 0.0;

    final withRumour = eligible.where((p) => p.hasRumour).length;
    return (withRumour / eligible.length).clamp(0.0, 1.0);
  }

  static bool _isDealerOneVOne(List<Player> players) {
    final enabled = players.where((p) => p.isEnabled && p.isAlive).toList();
    if (enabled.length != 2) return false;

    final a = enabled[0];
    final b = enabled[1];

    final aIsDealer = a.alliance.toLowerCase().contains('dealer');
    final bIsDealer = b.alliance.toLowerCase().contains('dealer');

    final aIsParty = a.alliance.toLowerCase().contains('party');
    final bIsParty = b.alliance.toLowerCase().contains('party');

    return (aIsDealer && bIsParty) || (bIsDealer && aIsParty);
  }
}
