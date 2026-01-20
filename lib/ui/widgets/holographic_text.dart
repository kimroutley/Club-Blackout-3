import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class HolographicText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double intensity;

  const HolographicText(
    this.text, {
    super.key,
    required this.style,
    this.intensity = 1.0,
  });

  @override
  State<HolographicText> createState() => _HolographicTextState();
}

class _HolographicTextState extends State<HolographicText> {
  // Use ValueNotifier for performance - avoids full rebuilds
  final ValueNotifier<double> _xOffset = ValueNotifier(0.0);
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _gyroSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      if (!mounted) return;
      // Y-rotation tilts the screen left/right -> shifts channels on X axis
      final double targetOffset = event.y * 2.0 * widget.intensity;

      // Update value directly. ValueListenableBuilder will handle the rest.
      _xOffset.value = targetOffset;
    });
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    _xOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _xOffset,
      builder: (context, val, child) {
        // Clamp offset to prevent too much separation
        final double offset = val.clamp(-5.0, 5.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Red Channel (Left shift)
            Transform.translate(
              offset: Offset(offset, 0),
              child: Opacity(
                opacity: 0.5,
                child: Text(
                  widget.text,
                  style: widget.style.copyWith(
                    color: const Color(0xFFFF0000).withOpacity(0.5),
                    shadows: [],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Cyan Channel (Right shift)
            Transform.translate(
              offset: Offset(-offset, 0),
              child: Opacity(
                opacity: 0.5,
                child: Text(
                  widget.text,
                  style: widget.style.copyWith(
                    color: const Color(0xFF00FFFF).withOpacity(0.5),
                    shadows: [],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Main Channel (Anchor)
            Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
