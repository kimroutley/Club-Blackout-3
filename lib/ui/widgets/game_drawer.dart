import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';
import 'save_load_dialog.dart';

class GameDrawer extends StatelessWidget {
  final GameEngine? gameEngine;
  final VoidCallback? onGameLogTap;
  final VoidCallback? onHostDashboardTap;
  final VoidCallback? onContinueGameTap;
  final void Function(int index)? onNavigate;
  final int selectedIndex;

  const GameDrawer({
    super.key,
    this.gameEngine,
    this.onGameLogTap,
    this.onHostDashboardTap,
    this.onContinueGameTap,
    this.onNavigate,
    this.selectedIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final useM3 = gameEngine?.currentPhase == GamePhase.night;

    final accent = useM3
        ? cs.primary
        : switch (selectedIndex) {
            0 => ClubBlackoutTheme.neonBlue,
            1 => ClubBlackoutTheme.neonPink,
            2 => ClubBlackoutTheme.neonOrange,
            3 => ClubBlackoutTheme.neonGold,
            _ => ClubBlackoutTheme.neonPurple,
          };

    final labelStyle = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5);

    final canContinueGame =
      onContinueGameTap != null &&
      gameEngine != null &&
      gameEngine!.currentPhase != GamePhase.lobby;

    return NavigationDrawerTheme(
      data: NavigationDrawerThemeData(
        backgroundColor:
            useM3 ? cs.surfaceContainerLow : ClubBlackoutTheme.pureBlack,
        surfaceTintColor: useM3 ? cs.surfaceTint : Colors.transparent,
        indicatorColor: useM3
            ? cs.secondaryContainer.withValues(alpha: 0.75)
            : accent.withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
        ),
        elevation: useM3 ? 1 : 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            final selected = states.contains(WidgetState.selected);
            return labelStyle?.copyWith(
              color: selected
                  ? (useM3 ? cs.onSecondaryContainer : accent)
                  : cs.onSurface.withValues(alpha: 0.70),
              shadows: (!useM3 && selected)
                  ? ClubBlackoutTheme.textGlow(accent, intensity: 0.8)
                  : null,
            );
          },
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected
                  ? (useM3 ? cs.onSecondaryContainer : accent)
                  : cs.onSurface.withValues(alpha: 0.45),
              size: 22,
              shadows: (!useM3 && selected)
                  ? ClubBlackoutTheme.iconGlow(accent, intensity: 0.6)
                  : null,
            );
          },
        ),
      ),
      child: NavigationDrawer(
        selectedIndex: selectedIndex.clamp(0, 3),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onDestinationSelected: (index) {
          Navigator.pop(context);
          onNavigate?.call(index);
        },
        children: [
          _buildHeader(context, accent, useM3: useM3),

          ClubBlackoutTheme.gap16,

          const NavigationDrawerDestination(
            label: Text('HOME'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
          ),
          const NavigationDrawerDestination(
            label: Text('LOBBY'),
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_alt_rounded),
          ),
          const NavigationDrawerDestination(
            label: Text('GUIDES'),
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
          ),
          const NavigationDrawerDestination(
            label: Text('GAMES NIGHT'),
            icon: Icon(Icons.nights_stay_outlined),
            selectedIcon: Icon(Icons.nights_stay_rounded),
          ),
          
          if (gameEngine != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(
                height: 24,
                thickness: 1,
              ),
            ),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'GAME CONTROLS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
            ),
            const SizedBox(height: 8),

            if (canContinueGame)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DrawerTile(
                  label: 'Continue Game',
                  icon: Icons.play_arrow_rounded,
                  accent: useM3 ? cs.primary : ClubBlackoutTheme.neonGreen,
                  useM3: useM3,
                  onTap: () {
                    Navigator.pop(context);
                    onContinueGameTap?.call();
                  },
                ),
              ),

            if (onHostDashboardTap != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DrawerTile(
                  label: 'Host Dashboard',
                  icon: Icons.dashboard_customize_outlined,
                  accent: useM3 ? cs.primary : ClubBlackoutTheme.neonBlue,
                  useM3: useM3,
                  onTap: () {
                    Navigator.pop(context);
                    onHostDashboardTap?.call();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _DrawerTile(
                label: 'Save / Load',
                icon: Icons.save_outlined,
                accent: useM3 ? cs.tertiary : ClubBlackoutTheme.neonGreen,
                useM3: useM3,
                onTap: () async {
                  Navigator.pop(context);
                  await showDialog<bool>(
                    context: context,
                    builder: (ctx) => useM3
                        ? SaveLoadDialogM3(engine: gameEngine!)
                        : SaveLoadDialog(engine: gameEngine!),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _DrawerTile(
                label: 'Game Log',
                icon: Icons.receipt_long_outlined,
                accent: useM3 ? cs.primary : ClubBlackoutTheme.neonBlue,
                useM3: useM3,
                onTap: () {
                  Navigator.pop(context);
                  onGameLogTap?.call();
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(
                height: 24,
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _DrawerTile(
                label: 'Restart Lobby',
                icon: Icons.restart_alt_rounded,
                accent: useM3 ? cs.secondary : ClubBlackoutTheme.neonPurple,
                useM3: useM3,
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      final cs = Theme.of(ctx).colorScheme;
                      final tt = Theme.of(ctx).textTheme;
                      const accent = ClubBlackoutTheme.neonPurple;
                      return ClubAlertDialog(
                        title: Text(
                          'Start new game?',
                          style: (tt.titleLarge ?? const TextStyle()).copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        content: Text(
                          'This resets the current game back to the lobby and clears roles, but keeps the guest list.',
                          style: (tt.bodyMedium ?? const TextStyle()).copyWith(
                            color: cs.onSurface.withValues(alpha: 0.88),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent.withValues(alpha: 0.18),
                              foregroundColor: cs.onSurface,
                            ),
                            child: const Text('Start new'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm != true) return;
                  gameEngine!.resetToLobby(keepGuests: true, keepAssignedRoles: false);
                  onNavigate?.call(1);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _DrawerTile(
                label: 'Full Reset',
                icon: Icons.delete_forever_outlined,
                accent: useM3 ? cs.error : ClubBlackoutTheme.neonRed,
                useM3: useM3,
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      final cs = Theme.of(ctx).colorScheme;
                      final tt = Theme.of(ctx).textTheme;
                      const accent = ClubBlackoutTheme.neonRed;
                      return ClubAlertDialog(
                        title: Text(
                          'Full reset?',
                          style: (tt.titleLarge ?? const TextStyle()).copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        content: Text(
                          'This clears the entire roster and resets back to the lobby.',
                          style: (tt.bodyMedium ?? const TextStyle()).copyWith(
                            color: cs.onSurface.withValues(alpha: 0.88),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent.withValues(alpha: 0.18),
                              foregroundColor: cs.onSurface,
                            ),
                            child: const Text('Reset'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm != true) return;
                  gameEngine!.resetToLobby(keepGuests: false, keepAssignedRoles: false);
                  onNavigate?.call(1);
                },
              ),
            ),
          ],
          
          ClubBlackoutTheme.gap8,
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accent, {required bool useM3}) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 32,
        bottom: 32,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: useM3
            ? scheme.surfaceContainerLow
            : accent.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
            color: useM3
                ? scheme.outlineVariant.withValues(alpha: 0.3)
                : accent.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        gradient: useM3
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: useM3
                      ? null
                      : ClubBlackoutTheme.boxGlow(accent, intensity: 0.8),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CLUB BLACKOUT',
                    style: useM3
                        ? (tt.headlineSmall ?? const TextStyle()).copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: scheme.onSurface,
                            fontSize: 22,
                          )
                        : ClubBlackoutTheme.neonGlowTextStyle(
                            color: accent,
                            fontSize: 24,
                            letterSpacing: 3.5,
                            glowIntensity: 1.2,
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'HOST DASHBOARD V1.0',
                    style: TextStyle(
                      color: useM3
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                          : accent.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (gameEngine != null) ...[
            ClubBlackoutTheme.gap24,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: useM3
                    ? scheme.surfaceContainerHigh
                    : scheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: useM3
                      ? scheme.outlineVariant.withValues(alpha: 0.3)
                      : scheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.perm_identity, size: 16, color: accent.withValues(alpha: 0.8)),
                  ClubBlackoutTheme.hGap12,
                  Text(
                    'Guests Registered: ${gameEngine!.guests.length}',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: ClubBlackoutTheme.inset24,
      child: Center(
        child: Text(
          'A GAME BY KYRIAN CO.',
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.38),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool useM3;

  const _DrawerTile({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.useM3 = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: useM3
          ? Card(
              elevation: 0,
              color: scheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: ListTile(
                onTap: onTap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Icon(icon, color: accent.withValues(alpha: 0.9)),
                title: Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            )
          : Container(
              decoration: ClubBlackoutTheme.neonFrame(
                color: accent,
                opacity: 0.06,
                borderRadius: ClubBlackoutTheme.radiusSm,
                borderWidth: 1.0,
              ),
              child: ListTile(
                onTap: onTap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ClubBlackoutTheme.radiusSm),
                ),
                leading: Icon(
                  icon,
                  color: accent.withValues(alpha: 0.90),
                  shadows: ClubBlackoutTheme.iconGlow(accent, intensity: 0.35),
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.80),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ),
    );
  }
}
