import 'package:flutter/material.dart';

import '../styles.dart';
import 'neon_background.dart';

class NeonPageScaffold extends StatelessWidget {
  final String? backgroundAsset;
  final Color accentColor;
  final Widget child;
  final double maxWidth;
  final bool scroll;
  final bool showOverlay;
  final EdgeInsets? padding;
  final bool applyAppBarOffset;

  const NeonPageScaffold({
    super.key,
    required this.child,
    required this.accentColor,
    this.backgroundAsset,
    this.maxWidth = 820,
    this.scroll = true,
    this.showOverlay = true,
    this.padding,
    this.applyAppBarOffset = true,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final defaultPadding = padding ?? ClubBlackoutTheme.pagePadding;
    final topOffset = applyAppBarOffset ? (kToolbarHeight - 12) : 8.0;

    final content = SafeArea(
      top: false,
      child: Padding(
        // Account for the transparent AppBar in the main shell.
        // Pulled up slightly to maximize screen real estate.
        padding: EdgeInsets.only(top: topInset + topOffset),
        child: ClubBlackoutTheme.centeredConstrained(
          maxWidth: maxWidth,
          child: scroll
              ? SingleChildScrollView(
                  padding: defaultPadding,
                  child: child,
                )
              : Padding(
                  padding: defaultPadding,
                  child: SizedBox.expand(child: child),
                ),
        ),
      ),
    );

    return NeonBackground(
      backgroundAsset: backgroundAsset,
      accentColor: accentColor,
      showOverlay: showOverlay,
      child: content,
    );
  }
}

class NeonGlassCard extends StatelessWidget {
  final Color glowColor;
  final Widget child;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final bool showBorder;
  final double? borderRadius;

  const NeonGlassCard({
    super.key,
    required this.glowColor,
    required this.child,
    this.opacity = 0.7,
    this.padding,
    this.showBorder = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? 20;

    return DecoratedBox(
      decoration: showBorder
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            )
          : const BoxDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          color: ClubBlackoutTheme.pureBlack.withValues(alpha: opacity),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: showBorder
                ? BorderSide(color: glowColor.withValues(alpha: 0.55), width: 1)
                : BorderSide.none,
          ),
          child: Padding(
            padding: padding ?? ClubBlackoutTheme.cardPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}
