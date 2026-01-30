import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';
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
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.95),
    builder: (BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final tt = Theme.of(context).textTheme;
      return ClubAlertDialog(
        insetPadding: ClubBlackoutTheme.insetH16V24,
        title: Text(
          'Revealing for $playerName',
          style: (tt.titleLarge ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 820),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoleCardWidget(role: role, compact: false, factsContext: factsContext),
                if (subtitle != null || body != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainer,
                    child: Padding(
                      padding: ClubBlackoutTheme.inset16,
                      child: Column(
                        children: [
                          if (subtitle != null)
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: (tt.bodyLarge ?? const TextStyle()).copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (body != null) ...[
                            const SizedBox(height: 8),
                            body,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onComplete?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: role.color.withValues(alpha: 0.16),
              foregroundColor: cs.onSurface,
            ),
            child: const Text('I understand'),
          ),
        ],
      );
    },
  );
}
