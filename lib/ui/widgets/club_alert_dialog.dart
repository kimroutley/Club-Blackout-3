import 'package:flutter/material.dart';

import '../styles.dart';

/// AlertDialog wrapper that applies Club Blackout default paddings.
///
/// This is a lightweight substitute for a theme-level `AlertDialogTheme` in
/// Flutter SDKs where ThemeData does not expose `alertDialogTheme`.
class ClubAlertDialog extends StatelessWidget {
  final Widget? icon;
  final EdgeInsetsGeometry? iconPadding;
  final Color? iconColor;

  final Widget? title;
  final EdgeInsetsGeometry? titlePadding;
  final TextStyle? titleTextStyle;

  final Widget? content;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? contentTextStyle;

  final List<Widget>? actions;
  final EdgeInsetsGeometry? actionsPadding;
  final MainAxisAlignment? actionsAlignment;
  final OverflowBarAlignment? actionsOverflowAlignment;
  final VerticalDirection? actionsOverflowDirection;
  final double? actionsOverflowButtonSpacing;
  final EdgeInsetsGeometry? buttonPadding;

  final Color? backgroundColor;
  final double? elevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final Clip? clipBehavior;
  final ShapeBorder? shape;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;
  final bool scrollable;
  final EdgeInsets? insetPadding;
  final String? semanticLabel;

  const ClubAlertDialog({
    super.key,
    this.icon,
    this.iconPadding,
    this.iconColor,
    this.title,
    this.titlePadding,
    this.titleTextStyle,
    this.content,
    this.contentPadding,
    this.contentTextStyle,
    this.actions,
    this.actionsPadding,
    this.actionsAlignment,
    this.actionsOverflowAlignment,
    this.actionsOverflowDirection,
    this.actionsOverflowButtonSpacing,
    this.buttonPadding,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.clipBehavior,
    this.shape,
    this.alignment,
    this.constraints,
    this.scrollable = false,
    this.insetPadding,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: icon,
      iconPadding: iconPadding,
      iconColor: iconColor,
      title: title,
      titlePadding: titlePadding ?? ClubBlackoutTheme.alertTitlePadding,
      titleTextStyle: titleTextStyle,
      content: content,
      contentPadding: contentPadding ?? ClubBlackoutTheme.alertContentPadding,
      contentTextStyle: contentTextStyle,
      actions: actions,
      actionsPadding: actionsPadding ?? ClubBlackoutTheme.alertActionsPadding,
      actionsAlignment: actionsAlignment,
      actionsOverflowAlignment: actionsOverflowAlignment,
      actionsOverflowDirection: actionsOverflowDirection,
      actionsOverflowButtonSpacing: actionsOverflowButtonSpacing,
      buttonPadding: buttonPadding,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      clipBehavior: clipBehavior,
      shape: shape,
      alignment: alignment,
      constraints: constraints,
      scrollable: scrollable,
      insetPadding: insetPadding,
      semanticLabel: semanticLabel,
    );
  }
}
