import 'package:flutter/material.dart';

class FadeSlideTabBarView extends StatefulWidget {
  final List<Widget> children;
  final TabController? controller;
  final Duration duration;

  const FadeSlideTabBarView({
    super.key,
    required this.children,
    this.controller,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<FadeSlideTabBarView> createState() => _FadeSlideTabBarViewState();
}

class _FadeSlideTabBarViewState extends State<FadeSlideTabBarView> {
  TabController? _controller;
  int _currentIndex = 0;
  int _prevIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateController();
  }

  @override
  void didUpdateWidget(FadeSlideTabBarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _updateController();
    }
  }

  void _updateController() {
    final TabController? newController =
        widget.controller ?? DefaultTabController.maybeOf(context);

    if (newController == null) {
      _controller?.removeListener(_handleTabChange);
      _controller = null;
      return;
    }

    if (newController == _controller) return;

    if (_controller != null) {
      _controller!.removeListener(_handleTabChange);
    }

    _controller = newController;
    _controller!.addListener(_handleTabChange);
    _currentIndex = _controller!.index;
    _prevIndex = _currentIndex;
  }

  void _handleTabChange() {
    if (_controller!.index != _currentIndex) {
      setState(() {
        _prevIndex = _currentIndex;
        _currentIndex = _controller!.index;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null && widget.children.isNotEmpty) {
      return widget.children[0];
    }
    
    final int direction = _currentIndex > _prevIndex ? 1 : -1;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (_controller == null) return;
        final double velocity = details.primaryVelocity ?? 0;
        if (velocity < -300) { // Swipe Left -> Next
           if (_controller!.index < _controller!.length - 1) {
             _controller!.animateTo(_controller!.index + 1);
           }
        } else if (velocity > 300) { // Swipe Right -> Prev
           if (_controller!.index > 0) {
             _controller!.animateTo(_controller!.index - 1);
           }
        }
      },
      child: AnimatedSwitcher(
        duration: widget.duration,
        switchInCurve: Curves.easeOutQuad,
        switchOutCurve: Curves.easeInQuad,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.topLeft,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          // Retrieve the key to check if this is the incoming or outgoing child
          final isNew = (child.key as ValueKey<int>).value == _currentIndex;

          if (isNew) {
            // INCOMING: Slide from side + Fade In
            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.15 * direction, 0), 
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.8)),
                ),
                child: child,
              ),
            );
          } else {
            // OUTGOING: Fade Out (stationary)
            return FadeTransition(
              opacity: animation, // animation goes 1.0 -> 0.0 for outgoing (if reverse)
              child: child,
            );
          }
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: widget.children[_currentIndex],
        ),
      ),
    );
  }
}
