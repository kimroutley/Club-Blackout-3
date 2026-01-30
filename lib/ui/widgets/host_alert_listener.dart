import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';
import 'player_icon.dart';

/// Listens for host-facing alerts emitted by [GameEngine] and shows them once.
///
/// Usage: include in any screen that should surface host alerts.
class HostAlertListener extends StatefulWidget {
  final GameEngine engine;

  const HostAlertListener({super.key, required this.engine});

  @override
  State<HostAlertListener> createState() => _HostAlertListenerState();
}

class _HostAlertListenerState extends State<HostAlertListener> {
  int _lastSeenVersion = 0;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _lastSeenVersion = widget.engine.hostAlertVersion;
    widget.engine.addListener(_onEngineChanged);
  }

  @override
  void didUpdateWidget(covariant HostAlertListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      oldWidget.engine.removeListener(_onEngineChanged);
      _lastSeenVersion = widget.engine.hostAlertVersion;
      widget.engine.addListener(_onEngineChanged);
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChanged);
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;

    final engine = widget.engine;
    if (engine.hostAlertVersion == _lastSeenVersion) return;

    _lastSeenVersion = engine.hostAlertVersion;

    final title = engine.hostAlertTitle?.trim();
    final message = engine.hostAlertMessage?.trim();
    if (title == null || title.isEmpty || message == null || message.isEmpty) {
      return;
    }

    if (_showing) return;
    _showing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final cs = Theme.of(context).colorScheme;

      // Try to find a role matching the title
      final matchingRole = widget.engine.roleRepository.roles.firstWhereOrNull(
          (r) =>
              title.toLowerCase().contains(r.name.toLowerCase()) ||
              title
                  .toLowerCase()
                  .contains(r.id.toLowerCase().replaceAll('_', ' ')));

      final accent = matchingRole?.color ?? ClubBlackoutTheme.neonOrange;

      await showDialog<void>(
        context: context,
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return ClubAlertDialog(
            title: Row(
              children: [
                if (matchingRole != null) ...[
                  PlayerIcon(
                    assetPath: matchingRole.assetPath,
                    glowColor: accent,
                    glowIntensity: 0.0,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Icon(Icons.campaign_rounded, color: accent),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: (textTheme.titleLarge ?? const TextStyle()).copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: (textTheme.bodyLarge ?? const TextStyle()).copyWith(
                color: cs.onSurface.withValues(alpha: 0.9),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.16),
                  foregroundColor: cs.onSurface,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        setState(() {
          _showing = false;
        });
      } else {
        _showing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
