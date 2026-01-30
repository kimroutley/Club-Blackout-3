import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../screens/rumour_mill_screen.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';

class GameFabMenu extends StatefulWidget {
  final GameEngine gameEngine;

  /// Optional override for the primary FAB/menu accent.
  final Color? baseColor;

  const GameFabMenu({
    super.key,
    required this.gameEngine,
    this.baseColor,
  });

  @override
  State<GameFabMenu> createState() => _GameFabMenuState();
}

class _GameFabMenuState extends State<GameFabMenu> {
  bool _isOpen = false;

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
  }

  bool _hasRole(String roleId) {
    return widget.gameEngine.players
        .where((p) => p.isAlive && p.isEnabled)
        .any((p) => p.role.id == roleId);
  }

  Future<void> _openRumourMill(BuildContext context) async {
    setState(() => _isOpen = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RumourMillScreen(gameEngine: widget.gameEngine),
      ),
    );
  }

  Future<void> _openTabooList(BuildContext context) async {
    setState(() => _isOpen = false);
    await showDialog<void>(
      context: context,
      builder: (_) => _TabooListDialog(gameEngine: widget.gameEngine),
    );
  }

  Future<void> _openClingerOps(BuildContext context) async {
    setState(() => _isOpen = false);
    await showDialog<void>(
      context: context,
      builder: (_) => _ClingerOpsDialog(gameEngine: widget.gameEngine),
    );
  }

  Widget _menuButton({
    required String label,
    required VoidCallback onPressed,
    required Color accent,
    IconData? icon,
  }) {
    return Padding(
      padding: ClubBlackoutTheme.bottomInset8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: accent.withValues(alpha: 0.9),
            foregroundColor: ClubBlackoutTheme.contrastOn(accent),
            padding: ClubBlackoutTheme.controlPadding,
            shape: const RoundedRectangleBorder(
              borderRadius: ClubBlackoutTheme.borderRadiusMdAll,
            ),
          ),
          icon: Icon(icon ?? Icons.circle, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.baseColor ?? ClubBlackoutTheme.neonPurple;

    final canShowRumour = _hasRole('messy_bitch');
    final canShowTaboo = _hasRole('lightweight');
    final canShowClinger = _hasRole('clinger');

    final hasAnyAction = canShowRumour || canShowTaboo || canShowClinger;
    if (!hasAnyAction) {
      if (_isOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _isOpen = false);
          }
        });
      }
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isOpen) ...[
            if (canShowRumour)
              _menuButton(
                label: 'RUMOUR MILL',
                accent: ClubBlackoutTheme.rumourLavender,
                icon: Icons.campaign_rounded,
                onPressed: () => _openRumourMill(context),
              ),
            if (canShowTaboo)
              _menuButton(
                label: 'TABOO LIST',
                accent: ClubBlackoutTheme.neonOrange,
                icon: Icons.warning_rounded,
                onPressed: () => _openTabooList(context),
              ),
            if (canShowClinger)
              _menuButton(
                label: 'CLINGER OPS',
                accent: ClubBlackoutTheme.neonPink,
                icon: Icons.favorite_rounded,
                onPressed: () => _openClingerOps(context),
              ),
          ],
          _GlassCircleFabButton(
            key: const Key('game_fab_menu_main_btn'),
            onPressed: _toggle,
            accent: accent,
            isOpen: _isOpen,
            icon: Icons.flash_on_rounded,
          ),
        ],
      ),
    );
  }
}

class _GlassCircleFabButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color accent;
  final IconData icon;
  final bool isOpen;

  const _GlassCircleFabButton({
    super.key,
    required this.onPressed,
    required this.accent,
    required this.icon,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      tooltip: 'Menu',
      onPressed: onPressed,
      backgroundColor: accent.withValues(alpha: 0.92),
      foregroundColor: ClubBlackoutTheme.contrastOn(accent),
      elevation: 6,
      child: AnimatedRotation(
        turns: isOpen ? 0.125 : 0.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: Icon(isOpen ? Icons.close_rounded : icon, size: 24),
      ),
    );
  }
}

class _TabooListDialog extends StatefulWidget {
  final GameEngine gameEngine;

  const _TabooListDialog({required this.gameEngine});

  @override
  State<_TabooListDialog> createState() => _TabooListDialogState();
}

class _TabooListDialogState extends State<_TabooListDialog> {
  Player? get _lightweight {
    final lws = widget.gameEngine.players
        .where((p) => p.isAlive && p.isEnabled)
        .where((p) => p.role.id == 'lightweight')
        .toList();
    return lws.isEmpty ? null : lws.first;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lw = _lightweight;

    return ClubAlertDialog(
      title: const Text('Taboo list', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: lw == null
            ? Text(
                'No active Lightweight found.',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Lightweight: ${lw.name}',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (lw.tabooNames.isEmpty)
                    Text(
                      'No taboo names assigned.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    )
                  else
                    ...lw.tabooNames.map(
                      (name) => Card(
                        elevation: 0,
                        color: cs.surfaceContainer,
                        child: ListTile(
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Tap to mark violation'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            widget.gameEngine.markLightweightTabooViolation(
                              tabooName: name,
                              lightweightId: lw.id,
                            );
                            widget.gameEngine.refreshUi();
                            Navigator.of(context).maybePop();
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ClingerOpsDialog extends StatelessWidget {
  final GameEngine gameEngine;

  const _ClingerOpsDialog({required this.gameEngine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clingers = gameEngine.players
        .where((p) => p.isAlive && p.isEnabled)
        .where((p) => p.role.id == 'clinger')
        .toList();

    return ClubAlertDialog(
      title: const Text('Clinger ops', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: clingers.isEmpty
            ? Text(
                'No active Clinger found.',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: clingers.length,
                itemBuilder: (_, i) {
                  final c = clingers[i];
                  return Card(
                    elevation: 0,
                    color: cs.surfaceContainer,
                    child: ListTile(
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        'Freed: ${c.clingerFreedAsAttackDog} • Used: ${c.clingerAttackDogUsed}',
                        style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.9)),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
