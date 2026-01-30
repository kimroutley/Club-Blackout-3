import '../models/player.dart';

/// Minimal standalone night resolver kept for legacy unit tests.
///
/// The authoritative gameplay rules live in `GameEngine`; this is intentionally
/// small and deterministic so old tests can continue to validate core concepts
/// (protection, blocking, and basic victory checks).
class NightAction {
  final String roleId;
  final String targetId;
  final String actionType; // e.g. 'kill', 'protect', 'send_home'

  const NightAction({
    required this.roleId,
    required this.targetId,
    required this.actionType,
  });
}

class NightResult {
  final List<String> killedPlayerIds;
  final List<String> protectedPlayerIds;
  final Map<String, String> messages;

  const NightResult({
    required this.killedPlayerIds,
    required this.protectedPlayerIds,
    required this.messages,
  });
}

class NightResolver {
  NightResult resolve(List<Player> players, List<NightAction> actions) {
    final byId = <String, Player>{for (final p in players) p.id: p};
    final messages = <String, String>{};
    final killed = <String>[];
    final protected = <String>[];

    bool isActive(Player? p) => p != null && p.isAlive && p.isEnabled;

    final sentHomeIds = actions
        .where((a) => a.actionType == 'send_home')
        .map((a) => a.targetId)
        .toSet();

    // Any Dealer sent home blocks all dealer kills in these legacy tests.
    final dealerSentHome =
        sentHomeIds.any((id) => byId[id]?.role.id == 'dealer');

    final protectedTargets = actions
        .where((a) => a.actionType == 'protect')
        .map((a) => a.targetId)
        .toSet();

    for (final id in sentHomeIds) {
      if (!protected.contains(id)) protected.add(id);
      messages[id] = 'Sent home (protected).';
    }

    for (final id in protectedTargets) {
      if (!protected.contains(id)) protected.add(id);
      messages[id] = 'Protected.';
    }

    for (final action in actions.where((a) => a.actionType == 'kill')) {
      final target = byId[action.targetId];
      if (!isActive(target)) continue;

      if (dealerSentHome) {
        messages[action.targetId] = 'Blocked (Dealer sent home).';
        continue;
      }

      if (protectedTargets.contains(action.targetId)) {
        messages[action.targetId] = 'Kill blocked (protected).';
        continue;
      }

      if (target != null &&
          target.role.id == 'minor' &&
          target.minorHasBeenIDd == false) {
        messages[action.targetId] = 'Blocked (Minor immunity).';
        continue;
      }

      killed.add(action.targetId);
      messages[action.targetId] = 'Killed.';
    }

    return NightResult(
      killedPlayerIds: killed,
      protectedPlayerIds: protected,
      messages: messages,
    );
  }

  /// Legacy rule set used by the test suite:
  /// - Dealers only win in the final 1v1.
  /// - Dealers do not win at parity.
  /// - Club Manager blocks Dealer auto-victory.
  bool checkDealerVictory(List<Player> players) {
    final aliveEnabled =
        players.where((p) => p.isAlive && p.isEnabled).toList();
    final dealers = aliveEnabled.where((p) => p.role.id == 'dealer').length;

    final hasClubManager = aliveEnabled.any((p) => p.role.id == 'club_manager');
    if (hasClubManager) return false;

    final partyAnimals = aliveEnabled
        .where((p) => p.alliance.toLowerCase().contains('party'))
        .where((p) => p.role.id != 'club_manager')
        .length;

    return dealers == 1 && partyAnimals == 1;
  }

  bool checkPartyAnimalVictory(List<Player> players) {
    final aliveEnabled =
        players.where((p) => p.isAlive && p.isEnabled).toList();
    final dealers = aliveEnabled.where((p) => p.role.id == 'dealer').length;
    return dealers == 0;
  }
}
