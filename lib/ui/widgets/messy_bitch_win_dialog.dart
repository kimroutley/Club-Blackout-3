import 'package:flutter/material.dart';
import '../../models/player.dart';
import 'club_alert_dialog.dart';
import 'player_icon.dart';

class MessyBitchWinDialog extends StatelessWidget {
  final Player messyBitch;
  final VoidCallback onContinue;
  final VoidCallback onRestart;

  const MessyBitchWinDialog({
    super.key,
    required this.messyBitch,
    required this.onContinue,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final seed = Theme.of(context).colorScheme.primary;
    final theme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      useMaterial3: true,
    );
    final cs = theme.colorScheme;

    final accent = messyBitch.role.color;

    return Theme(
      data: theme,
      child: ClubAlertDialog(
        icon: PlayerIcon(
          assetPath: messyBitch.role.assetPath,
          glowColor: accent,
          glowIntensity: 0.20,
          size: 56,
        ),
        title: const Text('Messy Bitch victory'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${messyBitch.name} has successfully spread a rumour to every single guest.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'She takes her win and leaves the party in absolute chaos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: onRestart,
            child: const Text('End game & restart'),
          ),
          FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.exit_to_app_rounded),
            label: const Text('Kick her out & continue'),
          ),
        ],
      ),
    );
  }
}
