import 'package:flutter/material.dart';

import '../../models/player.dart';
import '../styles.dart';
import 'bulletin_dialog_shell.dart';
import 'role_card_widget.dart';
import 'role_facts_context.dart';

class RoleCardRevealDialog extends StatelessWidget {
  final Player player;
  final VoidCallback onConfirm;
  final RoleFactsContext? factsContext;

  const RoleCardRevealDialog({
    super.key,
    required this.player,
    required this.onConfirm,
    this.factsContext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const accent = ClubBlackoutTheme.neonPurple;
    return BulletinDialogShell(
      accent: accent,
      maxWidth: 560,
      insetPadding: ClubBlackoutTheme.dialogInsetPadding,
      title: Text(
        'CONFIRM TARGET',
        style: ClubBlackoutTheme.bulletinHeaderStyle(accent),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoleCardWidget(
            role: player.role,
            compact: false,
            allowFlip: false,
            tapToFlip: false,
            factsContext: factsContext,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: cs.onSurface.withValues(alpha: 0.7),
          ),
          child: const Text('CANCEL'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: ClubBlackoutTheme.neonButtonStyle(accent, isPrimary: true),
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text('CONFIRM'),
        ),
      ],
    );
  }
}
