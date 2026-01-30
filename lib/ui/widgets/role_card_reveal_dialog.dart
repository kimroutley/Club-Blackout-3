import 'package:flutter/material.dart';

import '../../models/player.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';
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
    return ClubAlertDialog(
      title: const Text(
        'Confirm target',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
