import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An ultra-minimalist, sleek circular spinner inspired by Apple & Vercel design.
/// Features a rotating arc with a tapered gradient trail and an optional subtle track.
class MinimalLoader extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color color;
  final bool showTrack;
  final Duration duration;

  const MinimalLoader({
    super.key,
    this.size = 24.0,
    this.strokeWidth = 2.2,
    this.color = Colors.white,
    this.showTrack = true,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<MinimalLoader> createState() => _MinimalLoaderState();
}

class _MinimalLoaderState extends State<MinimalLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * math.pi,
            child: CustomPaint(
              painter: _MinimalSpinnerPainter(
                color: widget.color,
                strokeWidth: widget.strokeWidth,
                showTrack: widget.showTrack,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MinimalSpinnerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool showTrack;

  _MinimalSpinnerPainter({
    required this.color,
    required this.strokeWidth,
    required this.showTrack,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Optional faint background track (Apple/Vercel subtle depth)
    if (showTrack) {
      final trackPaint = Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, trackPaint);
    }

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Gradient trail sweep: from 0 opacity to 100% opacity over ~270 degrees
    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: math.pi * 1.5,
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.35),
        color,
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );

    final arcPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 1.5,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MinimalSpinnerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showTrack != showTrack;
  }
}
