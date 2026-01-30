import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../styles.dart';
import 'player_icon.dart';

enum RoleTileVariant { compact, card }

class RoleTileWidget extends StatelessWidget {
  final Role role;
  final RoleTileVariant variant;
  final VoidCallback? onTap;

  const RoleTileWidget({
    super.key,
    required this.role,
    this.variant = RoleTileVariant.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final title = Text(
      role.name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: (tt.titleSmall ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );

    final subtitle = Text(
      role.alliance,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (tt.labelSmall ?? const TextStyle()).copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.2,
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
      side: BorderSide(color: role.color.withValues(alpha: 0.40)),
    );

    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: variant == RoleTileVariant.card
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PlayerIcon(
                  assetPath: role.assetPath,
                  glowColor: role.color,
                  size: 48,
                ),
                const SizedBox(height: 12),
                title,
                const SizedBox(height: 8),
                subtitle,
              ],
            )
          : Row(
              children: [
                PlayerIcon(
                  assetPath: role.assetPath,
                  glowColor: role.color,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      title,
                      subtitle,
                    ],
                  ),
                ),
              ],
            ),
    );

    return Semantics(
      button: onTap != null,
      label: '${role.name}, ${role.alliance}',
      child: Material(
        color: cs.surface.withValues(alpha: 0.40),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: role.color.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
