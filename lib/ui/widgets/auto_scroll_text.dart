import 'dart:async';

import 'package:flutter/material.dart';

/// A lightweight marquee that auto-scrolls horizontally when text overflows.
///
/// - If the text fits, it renders a normal [Text].
/// - If it overflows, it gently scrolls left/right in a loop.
class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  /// Pixels per second when scrolling.
  final double speed;

  /// Pause at each end of the scroll.
  final Duration endPause;

  /// Extra gap after the text before looping.
  final double gap;

  const AutoScrollText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
    this.speed = 36,
    this.endPause = const Duration(milliseconds: 650),
    this.gap = 24,
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> {
  final _controller = ScrollController();
  bool _shouldScroll = false;
  bool _running = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runMarquee() async {
    if (_running) return;
    _running = true;

    // Wait for layout.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    while (mounted && _shouldScroll) {
      if (!_controller.hasClients) break;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) break;

      await Future<void>.delayed(widget.endPause);
      if (!mounted) break;

      final toEndMs = (max / widget.speed * 1000).clamp(200, 20000).toInt();
      await _controller.animateTo(
        max,
        duration: Duration(milliseconds: toEndMs),
        curve: Curves.linear,
      );
      if (!mounted) break;

      await Future<void>.delayed(widget.endPause);
      if (!mounted) break;

      final backMs = (max / widget.speed * 1000).clamp(200, 20000).toInt();
      await _controller.animateTo(
        0,
        duration: Duration(milliseconds: backMs),
        curve: Curves.linear,
      );
    }

    _running = false;
  }

  bool _computeShouldScroll(
      BoxConstraints constraints, TextStyle effectiveStyle) {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: effectiveStyle),
      maxLines: widget.maxLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: constraints.maxWidth);

    return tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = widget.style ?? DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (context, constraints) {
        final should = _computeShouldScroll(constraints, effectiveStyle);

        if (_shouldScroll != should) {
          _shouldScroll = should;
          if (_shouldScroll) {
            // Schedule after the frame so the scroll extent is available.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _runMarquee();
            });
          } else {
            if (_controller.hasClients) {
              _controller.jumpTo(0);
            }
          }
        }

        if (!should) {
          return Text(
            widget.text,
            maxLines: widget.maxLines,
            overflow: TextOverflow.clip,
            textAlign: widget.textAlign,
            style: effectiveStyle,
          );
        }

        // Marquee mode: use a scroll view with a trailing gap to avoid hard looping.
        return ClipRect(
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.text,
                  maxLines: widget.maxLines,
                  overflow: TextOverflow.visible,
                  textAlign: widget.textAlign,
                  style: effectiveStyle,
                ),
                SizedBox(width: widget.gap),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A horizontally-scrollable container that can optionally auto-pan when
/// its content overflows.
class AutoScrollHStack extends StatefulWidget {
  final Widget child;
  final bool autoScroll;
  final double speed;
  final Duration endPause;

  const AutoScrollHStack({
    super.key,
    required this.child,
    this.autoScroll = true,
    this.speed = 48,
    this.endPause = const Duration(milliseconds: 650),
  });

  @override
  State<AutoScrollHStack> createState() => _AutoScrollHStackState();
}

class _AutoScrollHStackState extends State<AutoScrollHStack> {
  final ScrollController _controller = ScrollController();
  bool _running = false;
  DateTime _lastUserScroll = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _userRecentlyInteracted {
    final dt = DateTime.now().difference(_lastUserScroll);
    return dt < const Duration(seconds: 3);
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    while (mounted && widget.autoScroll) {
      if (!_controller.hasClients) break;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) break;
      if (_userRecentlyInteracted) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        continue;
      }

      await Future<void>.delayed(widget.endPause);
      if (!mounted) break;

      final toEndMs = (max / widget.speed * 1000).clamp(200, 20000).toInt();
      await _controller.animateTo(
        max,
        duration: Duration(milliseconds: toEndMs),
        curve: Curves.linear,
      );
      if (!mounted) break;

      await Future<void>.delayed(widget.endPause);
      if (!mounted) break;

      final backMs = (max / widget.speed * 1000).clamp(200, 20000).toInt();
      await _controller.animateTo(
        0,
        duration: Duration(milliseconds: backMs),
        curve: Curves.linear,
      );
    }

    _running = false;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.autoScroll) return;
      _run();
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is UserScrollNotification || n is ScrollUpdateNotification) {
          _lastUserScroll = DateTime.now();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: widget.child,
      ),
    );
  }
}
