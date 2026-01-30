import 'package:flutter/material.dart';

import '../styles.dart';

class NeonSectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final IconData? icon;
  final EdgeInsets padding;
  final double fontSize;
  final MainAxisAlignment alignment;

  const NeonSectionHeader({
    super.key,
    required this.title,
    required this.color,
    this.icon,
    this.padding = EdgeInsets.zero,
    this.fontSize = 18,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = ClubBlackoutTheme.glowTextStyle(
      base: ClubBlackoutTheme.headingStyle.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
      color: color,
    );

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color.withValues(alpha: 0.9)),
            ClubBlackoutTheme.hGap8,
          ],
          Flexible(
            child: Text(
              title,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
