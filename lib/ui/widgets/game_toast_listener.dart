import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../styles.dart';

/// Listens for short-lived gameplay toast messages emitted by [GameEngine]
/// and surfaces them as a compact, auto-dismissing dropdown toast.
///
/// Intended to be a subtle visual cue (non-blocking) during night actions.
class GameToastListener extends StatefulWidget {
  final GameEngine engine;

  /// How long the toast stays visible.
  final Duration duration;

  const GameToastListener({
    super.key,
    required this.engine,
    this.duration = const Duration(seconds: 1),
  });

  @override
  State<GameToastListener> createState() => _GameToastListenerState();
}

class _GameToastListenerState extends State<GameToastListener>
    with SingleTickerProviderStateMixin {
  int _lastSeenVersion = 0;
  Timer? _hideTimer;
  OverlayEntry? _entry;
  late final AnimationController _anim;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _lastSeenVersion = widget.engine.toastVersion;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _fade = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    widget.engine.addListener(_onEngineChanged);
  }

  @override
  void didUpdateWidget(covariant GameToastListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      oldWidget.engine.removeListener(_onEngineChanged);
      _lastSeenVersion = widget.engine.toastVersion;
      widget.engine.addListener(_onEngineChanged);
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChanged);
    _hideTimer?.cancel();
    _removeEntry();
    _anim.dispose();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _dismissToast({bool animate = true}) {
    _hideTimer?.cancel();
    if (_entry == null) return;

    if (!animate) {
      _removeEntry();
      return;
    }

    _anim.reverse().whenComplete(() {
      if (!mounted) return;
      _removeEntry();
    });
  }

  void _onEngineChanged() {
    if (!mounted) return;

    final engine = widget.engine;
    if (engine.toastVersion == _lastSeenVersion) return;
    _lastSeenVersion = engine.toastVersion;

    final title = engine.toastTitle?.trim();
    final message = engine.toastMessage?.trim();
    final actionLabel = engine.toastActionLabel;
    final onAction = engine.toastAction;

    if (message == null || message.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final cs = Theme.of(context).colorScheme;

      final matchingRole = (title == null || title.isEmpty)
          ? null
          : engine.roleRepository.roles.firstWhereOrNull(
              (r) =>
                  title.toLowerCase().contains(r.name.toLowerCase()) ||
                  title
                      .toLowerCase()
                      .contains(r.id.toLowerCase().replaceAll('_', ' ')),
            );

      final phaseAccent = engine.currentPhase == GamePhase.night
          ? ClubBlackoutTheme.neonPurple
          : ClubBlackoutTheme.neonOrange;
      final accent = matchingRole?.color ?? phaseAccent;

      // Replace any existing toast immediately (these can fire rapidly).
      _dismissToast(animate: false);

      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;

      final background = cs.surfaceContainerHigh.withValues(alpha: 0.96);
      final onBg = cs.onSurface.withValues(alpha: 0.92);

      _entry = OverlayEntry(
        builder: (ctx) {
          return Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _fade,
                    child: GestureDetector(
                      onTap: () => _dismissToast(),
                      child: Card(
                        elevation: 8,
                        color: background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.bolt_rounded, color: accent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      if (title != null && title.isNotEmpty)
                                        TextSpan(
                                          text: '$title: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.1,
                                            color: accent,
                                          ),
                                        ),
                                      TextSpan(
                                        text: message,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: onBg,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (actionLabel != null && onAction != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: TextButton(
                                    onPressed: () {
                                      onAction();
                                      _dismissToast();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: accent,
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(actionLabel.toUpperCase()),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      overlay.insert(_entry!);
      _anim.forward(from: 0);

      _hideTimer = Timer(widget.duration, () {
        if (!mounted) return;
        _dismissToast();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
