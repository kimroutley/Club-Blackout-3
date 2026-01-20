/// Deterministic night resolver for Club Blackout.
///
/// This provides a simple, testable entrypoint for night resolution that
/// encapsulates the ordered night-phase resolution while integrating with
/// the existing Player model.
///
/// Night Phase Execution Order (by priority level):
/// 1. Sober (priority 1) - Can send someone home (protect + block)
/// 2. Medic (priority 2) - Protects a player from death (if PROTECT mode)
/// 3. Bouncer (priority 2) - Checks a player's ID
/// 4. Roofi (priority 4) - Silences a player
/// 5. Dealers (priority 5) - Choose a victim to kill
/// 6. Finalize - Apply all effects and determine outcomes
///
/// Note: Lower priority numbers execute first. Ties are broken by the order
/// actions are processed in this resolver.
///
/// Usage:
/// ```dart
/// final resolver = NightResolver();
/// final actions = [
///   NightAction(roleId: RoleIds.medic, targetId: 'player1', actionType: 'protect'),
///   NightAction(roleId: RoleIds.dealer, targetId: 'player2', actionType: 'kill'),
/// ];
/// final result = resolver.resolve(players, actions);
/// ```
library;

import '../models/player.dart';

/// Role ID constants to avoid hard-coded strings.
class RoleIds {
  static const String dealer = 'dealer';
  static const String medic = 'medic';
  static const String bouncer = 'bouncer';
  static const String sober = 'sober';
  static const String roofi = 'roofi';
  static const String minor = 'minor';
  static const String seasonedDrinker = 'seasoned_drinker';
  static const String allyCat = 'ally_cat';
}

/// Alliance constants to avoid hard-coded strings.
class Alliances {
  static const String dealers = 'The Dealers';
  static const String partyAnimals = 'The Party Animals';
}

/// Represents a single night action by a role.
class NightAction {
  final String roleId;
  final String? targetId;
  final String actionType; // 'kill', 'protect', 'silence', 'check', 'send_home'
  final Map<String, dynamic>? metadata; // Optional additional data

  const NightAction({
    required this.roleId,
    this.targetId,
    required this.actionType,
    this.metadata,
  });
}

/// Result of night resolution.
class NightResolutionResult {
  final List<String> killedPlayerIds;
  final List<String> protectedPlayerIds;
  final List<String> silencedPlayerIds;
  final Map<String, String> messages; // playerId -> message

  const NightResolutionResult({
    this.killedPlayerIds = const [],
    this.protectedPlayerIds = const [],
    this.silencedPlayerIds = const [],
    this.messages = const {},
  });
}

/// Deterministic night resolver.
///
/// This resolver processes night actions in a well-defined priority order
/// and returns the results. It is designed to be stateless and testable.
class NightResolver {
  /// Resolve all night actions and return the result.
  ///
  /// [players] - The list of all players in the game.
  /// [actions] - The list of night actions to resolve.
  /// [currentDay] - Current day count (used for tracking silenced days).
  ///
  /// Returns a [NightResolutionResult] containing all the outcomes.
  NightResolutionResult resolve(
    List<Player> players,
    List<NightAction> actions, {
    int currentDay = 0,
  }) {
    final killedIds = <String>[];
    final protectedIds = <String>[];
    final silencedIds = <String>[];
    final messages = <String, String>{};

    // Find all active actions by type
    final soberActions = actions
        .where((a) => a.roleId == RoleIds.sober)
        .toList();
    final roofiActions = actions
        .where((a) => a.roleId == RoleIds.roofi)
        .toList();
    final medicActions = actions
        .where((a) => a.roleId == RoleIds.medic)
        .toList();
    final bouncerActions = actions
        .where((a) => a.roleId == RoleIds.bouncer)
        .toList();
    final dealerActions = actions
        .where((a) => a.roleId == RoleIds.dealer)
        .toList();

    // Track which players are sent home (protected and blocked)
    final sentHomeIds = <String>{};

    // PHASE 1: Sober (priority 1) - Send someone home
    for (final action in soberActions) {
      if (action.targetId != null && action.actionType == 'send_home') {
        sentHomeIds.add(action.targetId!);
        protectedIds.add(action.targetId!);
        messages[action.targetId!] = 'Sent home by The Sober';
      }
    }

    // PHASE 2: Medic (priority 2) - Protect someone
    for (final action in medicActions) {
      if (action.targetId != null && action.actionType == 'protect') {
        protectedIds.add(action.targetId!);
        messages[action.targetId!] = 'Protected by The Medic';
      }
    }

    // PHASE 3: Bouncer (priority 2) - Check IDs (informational only)
    for (final action in bouncerActions) {
      if (action.targetId != null && action.actionType == 'check') {
        messages[action.targetId!] = 'ID checked by The Bouncer';
      }
    }

    // PHASE 4: Roofi (priority 4) - Silence players
    for (final action in roofiActions) {
      if (action.targetId != null && action.actionType == 'silence') {
        silencedIds.add(action.targetId!);
        messages[action.targetId!] = 'Silenced by Roofi';
      }
    }
    // PHASE 5: Dealers (priority 5) - Kill someone
    for (final action in dealerActions) {
      if (action.targetId != null && action.actionType == 'kill') {
        final targetId = action.targetId!;

        // Check if any dealer was sent home by Sober
        // Note: Uses isActive which includes joinsNextNight check. This is intentional
        // because players joining next night shouldn't participate in current night actions.
        final dealersInGame = players.where(
          (p) => p.role.id == RoleIds.dealer && p.isActive,
        );
        final anyDealerSentHome = dealersInGame.any(
          (d) => sentHomeIds.contains(d.id),
        );

        if (anyDealerSentHome) {
          // If a dealer was sent home, no kills happen
          messages[targetId] = 'Kill blocked (Dealer sent home by Sober)';
          continue;
        }

        // Check if target is protected
        if (protectedIds.contains(targetId)) {
          messages[targetId] = 'Kill attempt blocked by protection';
          continue;
        }

        // Check for special immunities
        final target = _findPlayer(players, targetId);
        if (target == null) continue;

        // Check Minor immunity (if not ID'd by bouncer)
        if (target.role.id == RoleIds.minor && !target.minorHasBeenIDd) {
          messages[targetId] = 'Kill blocked (Minor immunity)';
          continue;
        }

        // Check Seasoned Drinker lives
        if (target.role.id == RoleIds.seasonedDrinker && target.lives > 1) {
          messages[targetId] = 'Life lost (Seasoned Drinker)';
          // Target loses a life but doesn't die (handled by caller)
          continue;
        }

        // Check Ally Cat lives
        if (target.role.id == RoleIds.allyCat && target.lives > 1) {
          messages[targetId] = 'Life lost (Ally Cat)';
          // Target loses a life but doesn't die (handled by caller)
          continue;
        }

        // Kill is successful
        killedIds.add(targetId);
        messages[targetId] = 'Killed by The Dealers';
      }
    }

    return NightResolutionResult(
      killedPlayerIds: killedIds,
      protectedPlayerIds: protectedIds,
      silencedPlayerIds: silencedIds,
      messages: messages,
    );
  }

  /// Check if dealers have reached parity (or majority) with party animals.
  ///
  /// Returns true if dealers win, false otherwise.
  ///
  /// Note: Uses player.alliance property which can change during the game
  /// (e.g., Second Wind conversion, Creep inheritance). This ensures victory
  /// checks reflect the current game state, not the original role assignments.
  bool checkDealerVictory(List<Player> players) {
    final alivePlayers = players
        .where((p) => p.isAlive && p.isEnabled)
        .toList();

    final dealerCount = alivePlayers
        .where((p) => p.alliance == Alliances.dealers)
        .length;
    final partyAnimalCount = alivePlayers
        .where((p) => p.alliance == Alliances.partyAnimals)
        .length;

    // Dealers win if they reach parity or majority
    return dealerCount > 0 && dealerCount >= partyAnimalCount;
  }

  /// Check if party animals have won (all dealers dead).
  ///
  /// Returns true if party animals win, false otherwise.
  ///
  /// Note: Uses player.alliance property which can change during the game.
  bool checkPartyAnimalVictory(List<Player> players) {
    final alivePlayers = players
        .where((p) => p.isAlive && p.isEnabled)
        .toList();

    final dealerCount = alivePlayers
        .where((p) => p.alliance == Alliances.dealers)
        .length;
    final partyAnimalCount = alivePlayers
        .where((p) => p.alliance == Alliances.partyAnimals)
        .length;

    // Party Animals win if all dealers are dead and at least one party animal is alive
    return dealerCount == 0 && partyAnimalCount > 0;
  }

  /// Helper to safely find a player by ID.
  ///
  /// Returns null if player not found.
  Player? _findPlayer(List<Player> players, String playerId) {
    try {
      return players.firstWhere((p) => p.id == playerId);
    } catch (e) {
      return null;
    }
  }
}
