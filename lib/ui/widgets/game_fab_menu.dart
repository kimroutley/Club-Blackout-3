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
            style: const TextStyle(
                fontWeight: FontWeight.w900, letterSpacing: 0.6),
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
    final tt = Theme.of(context).textTheme;
    final lw = _lightweight;

    return ClubAlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_rounded,
              color: ClubBlackoutTheme.neonOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Taboo list',
              style: (tt.titleLarge ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
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
                  ClubBlackoutTheme.gap12,
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
                          title: Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
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
    final tt = Theme.of(context).textTheme;
    final clingers = gameEngine.players
        .where((p) => p.isAlive && p.isEnabled)
        .where((p) => p.role.id == 'clinger')
        .toList();

    return ClubAlertDialog(
      title: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: ClubBlackoutTheme.neonPink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Clinger ops',
              style: (tt.titleLarge ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
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
                      title: Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        'Freed: ${c.clingerFreedAsAttackDog} • Used: ${c.clingerAttackDogUsed}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.9)),
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

/*

// Legacy/corrupted content below is intentionally disabled.

class _TabooListDialog extends StatefulWidget {
  final GameEngine gameEngine;

  const _TabooListDialog({required this.gameEngine});

  @override
  State<_TabooListDialog> createState() => _TabooListDialogState();
}

class _TabooListDialogState extends State<_TabooListDialog> {
  Player? get _activeLightweight {
    return widget.gameEngine.players
        .where((p) => p.isAlive && p.isEnabled)
        .where((p) => p.role.id == 'lightweight')
        .cast<Player?>()
        .firstWhere((p) => p != null, orElse: () => null);
  }

  List<Player> get _eligibleTargets {
    final lw = _activeLightweight;
    return widget.gameEngine.players
        .where((p) => p.isAlive && p.isEnabled)
        .where((p) => lw == null ? true : p.id != lw.id)
        .where((p) => p.role.id != GameEngine.hostRoleId)
        .toList();
  }

  Future<void> _confirmTabooViolation(Player lw, String tabooName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return BulletinDialogShell(
          accent: ClubBlackoutTheme.neonOrange,
          title: Text(
            'TABOO VIOLATION',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          showCloseButton: true,
          content: Text(
            'Mark that ${lw.name} spoke the taboo name "$tabooName"?\n\nThis will kill them immediately.',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.85)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: ClubBlackoutTheme.neonRed,
                foregroundColor:
                    ClubBlackoutTheme.contrastOn(ClubBlackoutTheme.neonRed),
              ),
              child: const Text('CONFIRM'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    widget.gameEngine.markLightweightTabooViolation(
      tabooName: tabooName,
      lightweightId: lw.id,
    );
    widget.gameEngine.refreshUi();
    if (mounted) setState(() {});
  }

  Future<void> _addTaboo(Player lw) async {
    final targets = _eligibleTargets
        .where((p) => !lw.tabooNames.contains(p.name))
        .toList();

    if (targets.isEmpty) return;

    final picked = await showDialog<Player?>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return BulletinDialogShell(
          accent: ClubBlackoutTheme.neonOrange,
          title: Text(
            'ADD TABOO NAME',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          showCloseButton: true,
          content: ListView.builder(
            shrinkWrap: true,
            itemCount: targets.length,
            itemBuilder: (_, i) {
              final p = targets[i];
              return ListTile(
                title: Text(p.name),
                onTap: () => Navigator.of(ctx).pop(p),
              );
            },
          ),
        );
      },
    );

    if (picked == null) return;
    lw.tabooNames.add(picked.name);
    widget.gameEngine.refreshUi();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lw = _activeLightweight;

    return BulletinDialogShell(
      accent: ClubBlackoutTheme.neonOrange,
      title: Text(
        'TABOO LIST',
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      showCloseButton: true,
      maxWidth: 520,
      content: lw == null
          ? Text(
              'No active Lightweight found.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Lightweight: ${lw.name}',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ClubBlackoutTheme.gap12,
                if (lw.tabooNames.isEmpty)
                  Text(
                    'No taboo names assigned.',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: lw.tabooNames.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: cs.onSurface.withValues(alpha: 0.12),
                      ),
                      itemBuilder: (_, i) {
                        final name = lw.tabooNames[i];
                        return ListTile(
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Tap to mark violation',
                            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                          ),
                          onTap: () => _confirmTabooViolation(lw, name),
                          trailing: IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              lw.tabooNames.remove(name);
                              widget.gameEngine.refreshUi();
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ClubBlackoutTheme.gap12,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _addTaboo(lw),
                    style: FilledButton.styleFrom(
                      backgroundColor: ClubBlackoutTheme.neonOrange,
                      foregroundColor: ClubBlackoutTheme.contrastOn(
                        ClubBlackoutTheme.neonOrange,
                      ),
                    ),
                    child: const Text('ADD TABOO NAME'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ClingerOpsDialog extends StatefulWidget {
  final GameEngine gameEngine;

  const _ClingerOpsDialog({required this.gameEngine});

  @override
  State<_ClingerOpsDialog> createState() => _ClingerOpsDialogState();
}

class _ClingerOpsDialogState extends State<_ClingerOpsDialog> {
  List<Player> get _clingers {
    return widget.gameEngine.players
        .where((p) => p.isAlive && p.isEnabled)
        .where((p) => p.role.id == 'clinger')
        .toList();
  }

  Player? _findPlayer(String? id) {
    if (id == null) return null;
    final matches = widget.gameEngine.players.where((p) => p.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clingers = _clingers;

                  ClubBlackoutTheme.hGap8,
                  Text(
                    'LIGHTWEIGHT:',
                    style: TextStyle(
                      color:
                          ClubBlackoutTheme.neonOrange.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  ClubBlackoutTheme.hGap8,
                  Expanded(
                    child: Text(
                      _lightweight.name,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ClubBlackoutTheme.gap16,
            if (_lightweight.tabooNames.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No taboo names assigned.',
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _lightweight.tabooNames.map((name) {
                  return Container(
                    decoration: ClubBlackoutTheme.neonFrame(
                      color: ClubBlackoutTheme.neonRed,
                      opacity: 0.15,
                      borderRadius: 12,
                      borderWidth: 1.0,
                    ),
                    child: InkWell(
                      onTap: () => _confirmTabooViolation(name),
                      borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            ClubBlackoutTheme.hGap4,
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              iconSize: 14,
                              icon: const Icon(Icons.close),
                              color: cs.onSurfaceVariant,
                              onPressed: () {
                                setState(() {
                                  _lightweight.tabooNames.remove(name);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ClubBlackoutTheme.gap24,
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (innerCtx) {
                        final cs = Theme.of(innerCtx).colorScheme;
                        final candidates = widget.gameEngine.players
                            .where(
                                (p) => !_lightweight.tabooNames.contains(p.name))
                            .toList();

                        return BulletinDialogShell(
                          accent: ClubBlackoutTheme.neonOrange,
                          maxWidth: 520,
                          title: Text(
                            'ADD TABOO NAME',
                            style: ClubBlackoutTheme.bulletinHeaderStyle(
                              ClubBlackoutTheme.neonOrange,
                            ),
                          ),
                          content: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 420),
                            child: candidates.isEmpty
                                ? Center(
                                    child: Text(
                                      'No available names.',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: candidates.length,
                                    separatorBuilder: (_, __) =>
                                        ClubBlackoutTheme.gap8,
                                    itemBuilder: (_, i) {
                                      final p = candidates[i];
                                      return Container(
                                        decoration:
                                            ClubBlackoutTheme.bulletinItemDecoration(
                                          color: ClubBlackoutTheme.neonOrange,
                                          opacity: 0.08,
                                        ),
                                        child: ListTile(
                                          title: Text(
                                            p.name,
                                            style: TextStyle(
                                              color: cs.onSurface
                                                  .withValues(alpha: 0.9),
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          trailing: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                          onTap: () {
                                            _addTaboo(p);
                                            Navigator.of(innerCtx).pop();
                                          },
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(innerCtx).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    cs.onSurface.withValues(alpha: 0.7),
                              ),
                              child: const Text('CLOSE'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('ADD'),
                  style: ClubBlackoutTheme.neonButtonStyle(
                    ClubBlackoutTheme.neonOrange,
                    isPrimary: false,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurface.withValues(alpha: 0.7),
                  ),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClingerDialog extends StatefulWidget {
  final GameEngine gameEngine;
  const _ClingerDialog({required this.gameEngine});

  @override
  State<_ClingerDialog> createState() => _ClingerDialogState();
}

class _ClingerDialogState extends State<_ClingerDialog> {
  // We can support multiple clingers if custom roles allowed, but usually 1.
  List<Player> get _clingers =>
      widget.gameEngine.players.where((p) => p.role.id == 'clinger').toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BulletinDialogShell(
      accent: ClubBlackoutTheme.neonGreen,
      maxWidth: 520,
      maxHeight: 720,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'CLINGER OPS',
            style: ClubBlackoutTheme.bulletinHeaderStyle(
              ClubBlackoutTheme.neonGreen,
            ),
          ),
          const Icon(
            Icons.link_rounded,
            color: ClubBlackoutTheme.neonGreen,
            size: 28,
          ),
        ],
      ),
      content: _clingers.isEmpty
          ? Center(
              child: Text(
                'No clingers in this game.',
                style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ListView.separated(
              itemCount: _clingers.length,
              separatorBuilder: (_, __) => ClubBlackoutTheme.gap16,
              itemBuilder: (ctx, index) {
                final clinger = _clingers[index];

                String? partnerName;
                final partnerId = clinger.clingerPartnerId;
                if (partnerId != null) {
                  for (final p in widget.gameEngine.players) {
                    if (p.id == partnerId) {
                      partnerName = p.name;
                      break;
                    }
                  }
                }

                final obsessionName = partnerName ?? '(none)';

                final canMarkUnleashed = clinger.isActive &&
                    !clinger.clingerFreedAsAttackDog &&
                    clinger.clingerPartnerId != null;

                return Container(
                  decoration: ClubBlackoutTheme.bulletinItemDecoration(
                    color: ClubBlackoutTheme.neonGreen,
                    opacity: 0.1,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 16,
                            color: ClubBlackoutTheme.neonGreen,
                          ),
                          ClubBlackoutTheme.hGap8,
                          Text(
                            clinger.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      ClubBlackoutTheme.gap4,
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Text(
                          'Obsession: $obsessionName',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      ClubBlackoutTheme.gap12,
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Attack Dog Unleashed',
                          style: TextStyle(
                            color: canMarkUnleashed
                                ? cs.onSurface
                                : cs.onSurface.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Freed from obsession',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                cs.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        value: clinger.clingerFreedAsAttackDog,
                        activeColor: ClubBlackoutTheme.neonRed,
                        inactiveThumbColor:
                            cs.onSurface.withValues(alpha: 0.4),
                        inactiveTrackColor:
                            cs.onSurface.withValues(alpha: 0.1),
                        onChanged: canMarkUnleashed
                            ? (value) {
                                if (!value) return;

                                final ok = widget.gameEngine
                                    .freeClingerFromObsession(clinger.id);
                                final msg = ok
                                    ? (partnerName != null
                                        ? '${clinger.name} was called "controller" by $partnerName and is now unleashed.'
                                        : '${clinger.name} is now unleashed.')
                                    : 'Unable to mark ${clinger.name} as unleashed.';

                                if (mounted) setState(() {});
                                widget.gameEngine.showToast(msg);
                              }
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: cs.onSurface.withValues(alpha: 0.7),
          ),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }
}

*/
