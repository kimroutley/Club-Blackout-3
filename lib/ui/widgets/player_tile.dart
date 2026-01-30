import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../styles.dart';
import 'auto_scroll_text.dart';
import 'player_icon.dart';

class PlayerTile extends StatelessWidget {
  final Player player;
  final GameEngine? gameEngine;
  final VoidCallback? onTap;
  final int? voteCount;
  final bool isCompact;
  final bool isSelected;
  final Color? tileColor;
  final String? subtitleOverride;
  final Widget? leading;
  final Widget? trailing;
  final bool showEffectChips;

  /// If true, effect chips render as a banner overlay across the tile
  /// (instead of a row below the subtitle).
  final bool effectChipsAsBanner;
  final bool wrapInCard;
  final bool? enabledOverride;
  final EdgeInsets? contentPadding;

  const PlayerTile({
    super.key,
    required this.player,
    this.gameEngine,
    this.onTap,
    this.voteCount,
    this.isCompact = false,
    this.isSelected = false,
    this.tileColor,
    this.subtitleOverride,
    this.leading,
    this.trailing,
    this.showEffectChips = true,
    this.effectChipsAsBanner = false,
    this.wrapInCard = true,
    this.enabledOverride,
    this.contentPadding,
  });

  static String _humanizeKey(String raw) {
    final s = raw.replaceAll('_', ' ').trim();
    if (s.isEmpty) return raw;
    return s
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1) : ''}')
        .join(' ');
  }

  static List<_EffectChip> _collectEffectChips({
    required Player player,
    required GameEngine? engine,
  }) {
    final chips = <_EffectChip>[];
    final seen = <String>{};

    Color? roleColor(String roleId) {
      if (engine == null) return null;
      try {
        return engine.players.where((p) => p.role.id == roleId).first.role.color;
      } catch (_) {
        return null;
      }
    }

    Color? byRoleOrTheme(String roleId, Color fallback) {
      return roleColor(roleId) ?? fallback;
    }

    void add(String label, {Color? color}) {
      final key = label.trim();
      if (key.isEmpty) return;
      if (seen.add(key)) {
        chips.add(_EffectChip(label: key, color: color));
      }
    }

    // Player-local status flags.
    if (!player.isAlive) {
      add('Dead');
    }
    if (!player.isEnabled) {
      add('Disabled');
    }
    if (player.lives > 1) {
      add('${player.lives} Lives',
          color: player.role.id == 'seasoned_drinker'
              ? ClubBlackoutTheme.neonMint
              : player.role.color);
    }
    if (player.joinsNextNight) {
      add('Joins Next Night');
    }
    if (player.soberSentHome) {
      add('Sent Home', color: byRoleOrTheme('sober', ClubBlackoutTheme.neonBlue));
    }

    // Persistent Bouncer / Minor flags.
    if (player.idCheckedByBouncer) {
      add('Checked ID',
          color: byRoleOrTheme('bouncer', ClubBlackoutTheme.neonBlue));
    }

    // Clinger status flags.
    if (player.role.id == 'clinger') {
      if (player.clingerFreedAsAttackDog) {
        add('Unleashed', color: ClubBlackoutTheme.neonRed);
      } else if (player.clingerPartnerId != null) {
        final obsessionLabel = (engine == null)
            ? 'Obsessed'
            : (() {
                try {
                  final partner = engine.players
                      .where((p) => p.id == player.clingerPartnerId)
                      .firstOrNull;
                  return partner == null
                      ? 'Obsessed'
                      : 'Obsessed: ${partner.name}';
                } catch (_) {
                  return 'Obsessed';
                }
              })();
        add(obsessionLabel, color: ClubBlackoutTheme.neonPink);
      }
      if (player.clingerAttackDogUsed) {
        add('Attack Used', color: ClubBlackoutTheme.neonOrange);
      }
    }
    if (player.role.id == 'minor') {
      if (player.minorHasBeenIDd) {
        add('Vulnerable', color: ClubBlackoutTheme.neonRed);
      } else {
        add('Immune', color: ClubBlackoutTheme.neonMint);
      }
    }
    if (engine != null) {
      final currentDay = engine.dayCount;
      if (player.alibiDay != null && player.alibiDay == currentDay) {
        add('Alibi: Vote Immunity (Today)',
            color: byRoleOrTheme('silver_fox', ClubBlackoutTheme.neonBlue));
      }
      if (player.silencedDay != null && player.silencedDay == currentDay) {
        add('Silenced', color: byRoleOrTheme('roofi', ClubBlackoutTheme.neonGreen));
      }
      if (player.blockedKillNight != null &&
          player.blockedKillNight == currentDay) {
        add('No Kill', color: byRoleOrTheme('roofi', ClubBlackoutTheme.neonGreen));
      }

      // Lightweight taboo: if any alive Lightweight has this name as taboo,
      // show an indicator on the target's tile.
      final isTabooName = engine.players
          .where((p) => p.isAlive && p.isEnabled && p.role.id == 'lightweight')
          .any((lw) => lw.tabooNames.contains(player.name));
      if (isTabooName) {
        add('Taboo',
            color: byRoleOrTheme('lightweight', ClubBlackoutTheme.neonOrange));
      }
    } else {
      // Without engine context, still surface longer-lived flags.
      if (player.silencedDay != null) {
        add('Silenced', color: byRoleOrTheme('roofi', ClubBlackoutTheme.neonGreen));
      }
      if (player.blockedKillNight != null) {
        add('No Kill', color: byRoleOrTheme('roofi', ClubBlackoutTheme.neonGreen));
      }
    }

    // Free-form status list.
    for (final s in player.statusEffects) {
      final key = s.trim().toLowerCase();
      if (key == 'club_manager_sighted') {
        add('Club Manager Sighted',
            color: byRoleOrTheme('club_manager', ClubBlackoutTheme.neonOrange));
      } else {
        add(_humanizeKey(s));
      }
    }

    // Engine-driven effects (pending selections, marks, etc.).
    if (engine != null) {
      const labelByKey = <String, String>{
        // Canonical night action keys
        'sober_sent_home': 'Sent Home',
        'protect': 'Protected',
        'kill': 'Marked',
        'bouncer_check': 'ID Check',
        'roofi': 'Roofied',
        'creep_target': 'Creep Target',
        'kill_clinger': 'Attack Dog Target',
        'clinger_obsession': 'Obsession',
        'lightweight_taboo': 'Taboo',
        'messy_bitch_rumour': 'Rumour',
        'messy_bitch_special_kill': 'Special Kill Target',
        'drama_swap_a': 'Swap Target A',
        'drama_swap_b': 'Swap Target B',
        'bartender_a': 'Paired (A)',
        'bartender_b': 'Paired (B)',
        'predator_mark': 'Marked (Predator)',
        'whore_deflect': "The Whore's Bitch",
        'silver_fox_alibi': 'Alibi',
        'medic_revive': 'Revive Target',

        // Legacy/alias keys used during step handling
        'dealer_act': 'Marked',
        'medic_protect': 'Protected',
        'bouncer_act': 'ID Check',
        'roofi_act': 'Roofied',
      };

      const roleByKey = <String, String>{
        'sober_sent_home': 'sober',
        'protect': 'medic',
        'medic_protect': 'medic',
        'medic_revive': 'medic',
        'kill': 'dealer',
        'dealer_act': 'dealer',
        'bouncer_check': 'bouncer',
        'bouncer_act': 'bouncer',
        'roofi': 'roofi',
        'roofi_act': 'roofi',
        'creep_target': 'creep',
        'kill_clinger': 'clinger',
        'clinger_obsession': 'clinger',
        'lightweight_taboo': 'lightweight',
        'messy_bitch_rumour': 'messy_bitch',
        'messy_bitch_special_kill': 'messy_bitch',
        'drama_swap_a': 'drama_queen',
        'drama_swap_b': 'drama_queen',
        'bartender_a': 'bartender',
        'bartender_b': 'bartender',
        'predator_mark': 'predator',
        'whore_deflect': 'whore',
        'silver_fox_alibi': 'silver_fox',
      };

      bool valueReferencesPlayer(dynamic value, String playerId,
          {int depth = 0}) {
        if (value == null) return false;
        if (identical(value, playerId)) return true;
        if (value is String) return value == playerId;
        if (value is Iterable) {
          for (final v in value) {
            if (valueReferencesPlayer(v, playerId, depth: depth + 1)) {
              return true;
            }
          }
          return false;
        }
        if (value is Map) {
          if (depth >= 2) return false;

          // Common shapes.
          final targetId = value['targetId'];
          if (targetId is String && targetId == playerId) return true;
          final targetIds = value['targetIds'];
          if (targetIds is Iterable && targetIds.contains(playerId)) return true;

          // Generic scan.
          for (final v in value.values) {
            if (valueReferencesPlayer(v, playerId, depth: depth + 1)) {
              return true;
            }
          }
        }
        return false;
      }

      engine.nightActions.forEach((key, value) {
        if (value == null) return;

        // Global flags (e.g., 'no_murders_tonight') don't belong on a per-player chip.
        if (!valueReferencesPlayer(value, player.id)) return;

        final label = labelByKey[key] ?? _humanizeKey(key);
        final roleId = roleByKey[key];

        Color? color;
        if (roleId != null) {
          // Provide a themed fallback if the role isn't currently present.
          final fallback = switch (roleId) {
            'medic' => ClubBlackoutTheme.neonRed,
            'bouncer' => ClubBlackoutTheme.neonBlue,
            'clinger' => ClubBlackoutTheme.neonOrange,
            'dealer' => ClubBlackoutTheme.neonPink,
            'roofi' => ClubBlackoutTheme.neonGreen,
            _ => csFallbackFromRole(roleId),
          };
          color = byRoleOrTheme(roleId, fallback);
        }

        add(label, color: color);
      });

      // Cross-player persistent targets (stored on other players).
      for (final p in engine.guests) {
        if (p.whoreDeflectionTargetId == player.id) {
          add("The Whore's Bitch", color: p.role.color);
        }
        if (p.creepTargetId == player.id) {
          add('Creep Target', color: p.role.color);
        }
        if (p.clingerPartnerId == player.id || player.clingerPartnerId == p.id) {
          // Color by the Clinger if present; otherwise by either participant.
          add('Linked', color: roleColor('clinger') ?? p.role.color);
        }
        if (p.predatorTargetId == player.id) {
          add('Marked (Predator)', color: p.role.color);
        }
        if (p.dramaQueenTargetAId == player.id || p.dramaQueenTargetBId == player.id) {
          add('Swap Target', color: p.role.color);
        }
      }
    }

    return chips;
  }

  static Widget _chip(BuildContext context, _EffectChip chip) {
    final c = chip.color ?? ClubBlackoutTheme.neonBlue;
    final bg = c.withValues(alpha: 0.12);
    final border = c.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        chip.label,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w900,
          color: c.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  static Color csFallbackFromRole(String roleId) {
    // Sensible fallbacks by family if a role player is missing.
    switch (roleId) {
      case 'club_manager':
        return ClubBlackoutTheme.neonOrange;
      case 'whore':
        return ClubBlackoutTheme.neonPink;
      case 'predator':
        return ClubBlackoutTheme.neonRed;
      case 'tea_spiller':
        return ClubBlackoutTheme.neonOrange;
      default:
        return ClubBlackoutTheme.neonBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = player.role.color;
    final subtitleText =
        subtitleOverride ?? '${player.role.name} · ${player.alliance}';

    final isEnabled = enabledOverride ?? player.isEnabled;

    final effectChips = showEffectChips
        ? _collectEffectChips(player: player, engine: gameEngine)
        : const <_EffectChip>[];

    final showBanner = effectChipsAsBanner && effectChips.isNotEmpty;

    final badge = voteCount == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: roleColor.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Text(
              voteCount.toString(),
              style: ClubBlackoutTheme.glowTextStyle(
                color: roleColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          );

    final resolvedTrailing = trailing ?? badge;

    Widget content = InkWell(
      onTap: onTap,
      borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
      child: Padding(
        padding: contentPadding ??
            EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: isCompact ? 8 : 12,
            ),
        child: Row(
          children: [
            // Role Icon with "Alive" status glow
            PlayerIcon(
              assetPath: player.role.assetPath,
              glowColor: roleColor,
              size: isCompact ? 38 : 48,
              isAlive: player.isAlive,
              isEnabled: isEnabled,
              glowIntensity: isSelected ? 1.2 : 0.8,
            ),
            const SizedBox(width: 16),
            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AutoScrollText(
                    player.name,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: isCompact ? 18 : 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isEnabled
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      shadows: isEnabled && isSelected
                          ? ClubBlackoutTheme.textGlow(roleColor)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AutoScrollText(
                    subtitleText,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isEnabled
                          ? roleColor.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                  if (!showBanner && effectChips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AutoScrollHStack(
                      autoScroll: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < effectChips.length; i++) ...[
                            _chip(context, effectChips[i]),
                            if (i != effectChips.length - 1)
                              const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (showBanner) const SizedBox(height: 28),
                ],
              ),
            ),
            if (resolvedTrailing != null) ...[
              const SizedBox(width: 8),
              resolvedTrailing,
            ],
          ],
        ),
      ),
    );

    if (showBanner) {
      content = ClipRRect(
        borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
        child: Stack(
          children: [
            content,
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < effectChips.length; i++) ...[
                      _chip(context, effectChips[i]),
                      if (i != effectChips.length - 1)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!wrapInCard) return content;

    final baseColor = tileColor ?? roleColor;

    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 8 : 12),
      child: Container(
        decoration: ClubBlackoutTheme.neonFrame(
          color: isSelected ? baseColor : baseColor.withValues(alpha: 0.5),
          borderRadius: 16, // M3 standard-ish, matches neonFrame default
          opacity: isSelected ? 0.3 : (isEnabled ? 0.6 : 0.3),
          borderWidth: isSelected ? 1.5 : 0.5,
          showGlow: isSelected,
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

class _EffectChip {
  final String label;
  final Color? color;

  const _EffectChip({required this.label, this.color});
}
