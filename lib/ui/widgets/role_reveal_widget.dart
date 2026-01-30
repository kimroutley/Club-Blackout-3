// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../../models/role.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';
import 'player_icon.dart';
import 'role_card_widget.dart';
import 'role_facts_context.dart';

Future<void> showRoleReveal(
  BuildContext context,
  Role role,
  String playerName, {
  String? subtitle,
  Widget? body,
  VoidCallback? onComplete,
  RoleFactsContext? factsContext,
}) {
  return showDialog(
    context: context,
    builder: (context) => ClubAlertDialog(
      title: Column(
        children: [
          PlayerIcon(
            assetPath: role.assetPath,
            glowColor: role.color,
            size: 60,
          ),
          const SizedBox(height: 12),
          Text(
            playerName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoleCardWidget(
              role: role,
              compact: false,
              allowFlip: false,
              tapToFlip: false,
              factsContext: factsContext,
            ),
            if (body != null) ...[
              const SizedBox(height: 24),
              body,
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onComplete?.call();
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

class RoleRevealWidget extends StatelessWidget {
  final Role role;
  final String playerName;
  final String? subtitle;
  final Widget? body;
  final VoidCallback? onComplete;
  final RoleFactsContext? factsContext;

  const RoleRevealWidget({
    super.key,
    required this.role,
    required this.playerName,
    this.subtitle,
    this.body,
    this.onComplete,
    this.factsContext,
  });

  @override
  Widget build(BuildContext context) {
    // This widget is primarily used as a builder for showDialog in legacy calls,
    // but the modern pattern prefers the top-level function.
    // We implement it here just in case it's embedded directly.
    return ClubAlertDialog(
      title: Column(
        children: [
          PlayerIcon(
            assetPath: role.assetPath,
            glowColor: role.color,
            size: 60,
          ),
          const SizedBox(height: 12),
          Text(
            playerName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoleCardWidget(
            role: role,
            compact: false,
            allowFlip: false,
            tapToFlip: false,
            factsContext: factsContext,
          ),
          if (body != null) ...[
            const SizedBox(height: 24),
            body!,
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: onComplete,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
