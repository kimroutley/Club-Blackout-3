import 'package:flutter/material.dart';

import '../models/player.dart';
import '../ui/styles.dart';
import 'game_engine.dart';

/// Represents a consolidated status to be displayed in the UI.
class PlayerStatusDisplay {
  final String label;
  final Color color;
  final String? description;
  final IconData? icon;

  PlayerStatusDisplay({
    required this.label,
    required this.color,
    this.description,
    this.icon,
  });
}

/// Centralizes logic for resolving all player statuses (Effects + Role State).
class PlayerStatusResolver {
  /// Returns a list of all active statuses for a player.
  /// Used by Host Status Cards, Voting Tiles, and Act screens.
  static List<PlayerStatusDisplay> resolveStatus(
    Player player,
    GameEngine gameEngine,
  ) {
    final List<PlayerStatusDisplay> statuses = [];

    // 1. Messy Bitch - Rumour
    if (player.hasRumour) {
      statuses.add(
        PlayerStatusDisplay(
          label: 'RUMOUR',
          color: ClubBlackoutTheme.neonPurple,
          description: 'This player has heard a dirty rumour.',
          icon: Icons.record_voice_over,
        ),
      );
    }

    // 2. Generic Status Effects (from StatusEffectManager)
    final effects = gameEngine.statusEffectManager.getEffects(player.id);
    for (var effect in effects) {
      // Skip legacy silenced flag if duplicately applied (handled by role state below)
      if (effect.name.contains('SILENCED') &&
          player.silencedDay == gameEngine.dayCount) {
        continue;
      }

      String label = effect.name.toUpperCase();
      if (effect.duration > 0) {
        label += " (${effect.duration} TURN${effect.duration > 1 ? 'S' : ''})";
      } else if (effect.isPermanent) {
        label += ' (PERM)';
      }

      statuses.add(
        PlayerStatusDisplay(
          label: label,
          color: ClubBlackoutTheme.neonBlue,
          description: effect.description,
          icon: Icons.info_outline,
        ),
      );
    }

    // 3. Sober - Sent Home
    if (player.soberSentHome) {
      statuses.add(
        PlayerStatusDisplay(
          label: 'SENT HOME',
          color: ClubBlackoutTheme.neonBlue,
          description: 'Sent home by the Sober. Cannot act or vote.',
          icon: Icons.home,
        ),
      );
    }

    // 4. Clinger - Obsession
    if (player.clingerPartnerId != null) {
      final target = gameEngine.players.firstWhere(
        (p) => p.id == player.clingerPartnerId,
        orElse: () => player,
      );
      statuses.add(
        PlayerStatusDisplay(
          label: 'OBSESSED: ${target.name}',
          color: ClubBlackoutTheme.neonPink,
          description: 'Bound to ${target.name}. If they die, you die.',
          icon: Icons.favorite,
        ),
      );
    }

    // 5. Creep - Target
    if (player.creepTargetId != null) {
      final target = gameEngine.players.firstWhere(
        (p) => p.id == player.creepTargetId,
        orElse: () => player,
      );
      statuses.add(
        PlayerStatusDisplay(
          label: 'CREEPING: ${target.name}',
          color: ClubBlackoutTheme.neonGreen,
          description: 'Mimicking ${target.name}.',
          icon: Icons.remove_red_eye,
        ),
      );
    }

    // 6. Clinger - Unleashed (Attack Dog)
    if (player.clingerFreedAsAttackDog) {
      statuses.add(
        PlayerStatusDisplay(
          label: 'UNLEASHED',
          color: ClubBlackoutTheme.neonRed,
          description: 'Freed from obsession. Can kill once.',
          icon: Icons.dangerous,
        ),
      );
    }

    // 7. Medic - Choice
    if (player.medicChoice != null) {
      statuses.add(
        PlayerStatusDisplay(
          label: player.medicChoice == 'PROTECT_DAILY'
              ? 'MEDIC: PROTECT'
              : 'MEDIC: REVIVE',
          color: ClubBlackoutTheme.neonBlue,
          description:
              'Permanent Night 0 Choice: ${player.medicChoice == 'PROTECT_DAILY' ? 'Protect one player each night' : 'Revive one player once per game'}',
          icon: Icons.medical_services,
        ),
      );
    }

    // 8. Bouncer - ID Checked
    if (player.idCheckedByBouncer) {
      statuses.add(
        PlayerStatusDisplay(
          label: 'CHECKED',
          color: Colors.grey,
          description: 'ID has been checked by the Bouncer.',
          icon: Icons.check,
        ),
      );
    }

    // 9. Roofi - Silenced
    if (player.silencedDay == gameEngine.dayCount) {
      statuses.add(
        PlayerStatusDisplay(
          label: 'SILENCED',
          color: ClubBlackoutTheme.pureWhite,
          description: 'Silenced for today.',
          icon: Icons.mic_off,
        ),
      );
    }

    // 10. Minor - Immunity / Vulnerable state
    if (player.role.id == 'minor') {
      if (player.minorHasBeenIDd) {
        statuses.add(
          PlayerStatusDisplay(
            label: 'VULNERABLE',
            color: ClubBlackoutTheme.neonRed,
            description: 'The Minor can now be killed by the Dealers.',
            icon: Icons.warning_amber_rounded,
          ),
        );
      } else {
        statuses.add(
          PlayerStatusDisplay(
            label: 'IMMUNE',
            color: ClubBlackoutTheme.neonMint,
            description:
                'Immune to Dealer kills until ID checked by the Bouncer.',
            icon: Icons.shield_outlined,
          ),
        );
      }
    }

    // 10b. Silver Fox - Alibi (Vote Immunity)
    if (player.alibiDay == gameEngine.dayCount) {
      statuses.add(
        PlayerStatusDisplay(
          label: 'ALIBI (TODAY ONLY)',
          color: ClubBlackoutTheme.neonBlue,
          description: 'Votes against this player do not count today.',
          icon: Icons.verified_user,
        ),
      );
    }

    // 11. Second Wind - Status
    if (player.secondWindConverted) {
      statuses.add(
        PlayerStatusDisplay(
          label: 'CONVERTED FROM SECOND',
          color: ClubBlackoutTheme.neonOrange,
          description: 'Converted to Dealer team.',
          icon: Icons.cached,
        ),
      );
    } else if (player.secondWindPendingConversion) {
      statuses.add(
        PlayerStatusDisplay(
          label: 'PENDING CONV',
          color: ClubBlackoutTheme.neonOrange,
          description: 'Pending Dealer conversion decision.',
          icon: Icons.hourglass_empty,
        ),
      );
    }

    // 12. Late Joiner
    if (player.joinsNextNight) {
      statuses.add(
        PlayerStatusDisplay(
          label: 'LATE JOIN',
          color: ClubBlackoutTheme.neonGreen,
          description: 'Will join the game next night.',
          icon: Icons.person_add,
        ),
      );
    }

    return statuses;
  }
}
