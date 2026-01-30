import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../styles.dart';
import '../widgets/club_alert_dialog.dart';
import 'bulletin_dialog_shell.dart';

class DramaQueenSwapDialog extends StatefulWidget {
  final GameEngine gameEngine;
  final Function(Player, Player) onConfirm;

  const DramaQueenSwapDialog({
    super.key,
    required this.gameEngine,
    required this.onConfirm,
  });

  @override
  State<DramaQueenSwapDialog> createState() => _DramaQueenSwapDialogState();
}

class _DramaQueenSwapDialogState extends State<DramaQueenSwapDialog> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    // Pre-select if marked
    if (widget.gameEngine.dramaQueenMarkedAId != null) {
      _selectedIds.add(widget.gameEngine.dramaQueenMarkedAId!);
    }
    if (widget.gameEngine.dramaQueenMarkedBId != null) {
      _selectedIds.add(widget.gameEngine.dramaQueenMarkedBId!);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length < 2) {
          _selectedIds.add(id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNight = widget.gameEngine.currentPhase == GamePhase.night;
    final cs = Theme.of(context).colorScheme;
    // Filter logic: Living players only. Drama Queen is dead, so she won't be in this list naturally if we filter isAlive.
    // Unless she revived? Unlikely.
    final candidates = widget.gameEngine.players
        .where((p) => p.isAlive && p.isEnabled)
        .toList();

    final canConfirm = _selectedIds.length == 2;

    Widget buildGrid() {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: candidates.length,
        itemBuilder: (context, index) {
          final p = candidates[index];
          final selected = _selectedIds.contains(p.id);

          return InkWell(
            onTap: () => _toggle(p.id),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? (isNight
                        ? cs.secondaryContainer
                        : ClubBlackoutTheme.neonPurple.withValues(alpha: 0.25))
                    : (isNight ? cs.surfaceContainerHighest : Colors.white10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? (isNight ? cs.secondary : ClubBlackoutTheme.neonPurple)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                p.name,
                style: TextStyle(
                  color: selected
                      ? (isNight ? cs.onSecondaryContainer : Colors.white)
                      : (isNight ? cs.onSurface : Colors.white70),
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      );
    }

    if (isNight) {
      return ClubAlertDialog(
        title: const Text('Drama Queen Retaliation'),
        content: SizedBox(
          width: 640,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose two players to swap roles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: buildGrid()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: canConfirm
                ? () {
                    final list = _selectedIds.toList();
                    final p1 = candidates.firstWhere((p) => p.id == list[0]);
                    final p2 = candidates.firstWhere((p) => p.id == list[1]);
                    widget.onConfirm(p1, p2);
                    Navigator.pop(context);
                  }
                : null,
            child: const Text('Confirm Swap'),
          ),
        ],
      );
    }

    const accent = ClubBlackoutTheme.neonPurple;
    return BulletinDialogShell(
      accent: accent,
      maxWidth: 640,
      maxHeight: 800,
      insetPadding: ClubBlackoutTheme.dialogInsetPadding,
      title: Text(
        'DRAMA QUEEN RETALIATION',
        style: ClubBlackoutTheme.bulletinHeaderStyle(accent),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose two players to swap roles.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: buildGrid(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('SKIP (NO SWAP)'),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () {
                  final list = _selectedIds.toList();
                  final p1 = candidates.firstWhere((p) => p.id == list[0]);
                  final p2 = candidates.firstWhere((p) => p.id == list[1]);
                  widget.onConfirm(p1, p2);
                  Navigator.pop(context);
                }
              : null,
          style: ClubBlackoutTheme.neonButtonStyle(accent, isPrimary: true),
          child: const Text('CONFIRM SWAP'),
        ),
      ],
    );
  }
}
