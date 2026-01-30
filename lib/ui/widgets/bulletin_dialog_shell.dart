import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../styles.dart';

class BulletinDialogShell extends StatelessWidget {
  final Color accent;
  final Widget? title;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;
  final EdgeInsets insetPadding;
  final bool showCloseButton;

  const BulletinDialogShell({
    super.key,
    required this.accent,
    this.title,
    required this.content,
    this.actions = const [],
    this.maxWidth = 420,
    this.maxHeight,
    this.padding = const EdgeInsets.all(24),
    this.insetPadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.showCloseButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(ClubBlackoutTheme.radiusLg);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 30,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 34,
                spreadRadius: 6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.surface.withValues(alpha: 0.92),
                      cs.surface.withValues(alpha: 0.78),
                    ],
                  ),
                ),
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null || showCloseButton) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: title ?? const SizedBox.shrink()),
                          if (showCloseButton)
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Close',
                              style: IconButton.styleFrom(
                                foregroundColor: cs.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    Flexible(child: content),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
