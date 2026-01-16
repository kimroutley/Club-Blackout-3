import '../models/player.dart';
import '../models/role.dart';

class RoleValidationResult {
  final bool isValid;
  final String? error;
  final List<String> warnings;

  const RoleValidationResult({
    required this.isValid,
    this.error,
    this.warnings = const [],
  });

  RoleValidationResult.valid() : isValid = true, error = null, warnings = const [];
  RoleValidationResult.invalid(String message) : isValid = false, error = message, warnings = const [];
}

class RoleValidator {
  // Roles that can have multiple instances
  static const Set<String> multipleAllowedRoles = {
    'dealer',
    'party_animal',
  };

  /// Recommended Dealer scaling: 1 Dealer per 7 total players.
  /// This matches "for every 6 other roles, add an extra Dealer".
  static int recommendedDealerCount(int enabledPlayerCount) {
    if (enabledPlayerCount <= 0) return 0;
    return (enabledPlayerCount / 7).ceil();
  }

  /// Validates if a role can be assigned to a player
  static RoleValidationResult canAssignRole(Role? role, String playerId, List<Player> allPlayers) {
    if (role == null) {
      return RoleValidationResult.valid();
    }

    // Allow multiple dealers and party animals
    if (multipleAllowedRoles.contains(role.id)) {
      return RoleValidationResult.valid();
    }

    // Check if this unique role is already assigned to another player
    final existingPlayer = allPlayers.firstWhere(
      (p) => p.id != playerId && p.role.id == role.id && p.isEnabled,
      orElse: () => Player(
        id: 'none',
        name: '',
        role: Role(
          id: 'none',
          name: '',
          alliance: '',
          type: '',
          description: '',
          nightPriority: 0,
          assetPath: '',
          colorHex: '#FFFFFF',
        ),
      ),
    );

    if (existingPlayer.id != 'none') {
      return RoleValidationResult.invalid(
        '${role.name} can only exist once in the game. ${existingPlayer.name} already has this role.'
      );
    }

    return RoleValidationResult.valid();
  }

  /// Validates the entire game setup before starting
  static RoleValidationResult validateGameSetup(List<Player> players) {
    if (players.isEmpty) {
      return RoleValidationResult.invalid('No players added to the game.');
    }

    final enabledPlayers = players.where((p) => p.isEnabled).toList();

    if (enabledPlayers.isEmpty) {
      return RoleValidationResult.invalid('All players are toggled off.');
    }

    final List<String> warnings = [];

    // Count role types
    int dealerCount = 0;
    bool hasMedic = false;
    bool hasBouncer = false;
    bool hasPartyAnimal = false;
    bool hasWallflower = false;

    for (var player in enabledPlayers) {
      if (player.role.id == 'dealer') {
        dealerCount++;
      } else if (player.role.id == 'medic') {
        hasMedic = true;
      } else if (player.role.id == 'bouncer') {
        hasBouncer = true;
      } else if (player.role.id == 'party_animal') {
        hasPartyAnimal = true;
      } else if (player.role.id == 'wallflower') {
        hasWallflower = true;
      }
    }

    // Enforce uniqueness for all non-dealer roles.
    final seenUniqueRoleIds = <String>{};
    for (final player in enabledPlayers) {
      final roleId = player.role.id;
      if (multipleAllowedRoles.contains(roleId) || roleId == 'temp') continue;
      if (!seenUniqueRoleIds.add(roleId)) {
        return RoleValidationResult.invalid('Duplicate role detected: $roleId. Only Dealers and Party Animals can repeat.');
      }
    }

    // Check required roles
    if (dealerCount == 0) {
      return RoleValidationResult.invalid('Game requires at least 1 Dealer.');
    }

    if (!hasPartyAnimal) {
      return RoleValidationResult.invalid('Game requires at least 1 Party Animal.');
    }

    if (!hasWallflower) {
      return RoleValidationResult.invalid('Game requires at least 1 Wallflower.');
    }

    final recommendedDealers = recommendedDealerCount(enabledPlayers.length);
    if (dealerCount < recommendedDealers) {
      warnings.add('Recommended: $recommendedDealers Dealer(s) for ${enabledPlayers.length} players.');
    }

    // Count total Party Animal-aligned roles (Party Animals + any role aligned with The Party Animals)
    final partyAlignedCount = enabledPlayers.where((p) {
      final alliance = p.role.alliance;
      final startAlliance = p.role.startAlliance;
      return alliance == 'The Party Animals' || p.role.id == 'party_animal' || startAlliance == 'PARTY_ANIMAL';
    }).length;

    if (partyAlignedCount < 2) {
      return RoleValidationResult.invalid('Game requires at least 2 Party Animal alliance members.');
    }

    if (!hasMedic && !hasBouncer) {
      return RoleValidationResult.invalid('Game requires at least 1 Medic and/or 1 Bouncer.');
    }

    // Warnings (not blocking)
    if (dealerCount > enabledPlayers.length ~/ 3) {
      warnings.add('Warning: High dealer-to-player ratio may make the game difficult for Party Animals.');
    }

    return RoleValidationResult(
      isValid: true,
      error: null,
      warnings: warnings,
    );
  }

  /// Get available roles for a player (excludes already-taken unique roles)
  static List<Role> getAvailableRoles(List<Role> allRoles, String playerId, List<Player> allPlayers) {
    final available = allRoles.where((role) {
      final validation = canAssignRole(role, playerId, allPlayers);
      return validation.isValid;
    }).toList();
    available.sort((a, b) => a.name.compareTo(b.name));
    return available;
  }
}
