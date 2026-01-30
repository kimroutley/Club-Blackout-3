import 'package:flutter/material.dart';

import '../styles.dart';

class PhaseCard extends StatelessWidget {
  final String phaseName;
  final String? subtitle;
  final Color phaseColor;
  final IconData phaseIcon;
  final bool isActive;

  const PhaseCard({
    super.key,
    required this.phaseName,
    this.subtitle,
    required this.phaseColor,
    required this.phaseIcon,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: isActive
          ? cs.surfaceContainerHighest.withValues(alpha: 0.55)
          : cs.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: ClubBlackoutTheme.borderRadiusMdAll,
        side: BorderSide(color: phaseColor.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        leading: Icon(phaseIcon, color: phaseColor),
        title: Text(
          phaseName,
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
      ),
    );
  }
}
