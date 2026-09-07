import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The original ethereal blue AI animated gradient background.
/// Features luminous, drifting electric cyan, azure blue, and indigo orbs
/// with smooth 14-second continuous harmonic motion.
class AiGradientBackground extends StatefulWidget {
  final Widget child;
  final double intensity;

  const AiGradientBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
  });

  @override
  State<AiGradientBackground> createState() => _AiGradientBackgroundState();
}

class _AiGradientBackgroundState extends State<AiGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Pitch-black dark base
        Positioned.fill(
          child: Container(color: AppTheme.background),
        ),

        // Animated luminous Blue AI gradient aura
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _OriginalBlueAiGradientPainter(
                  progress: _controller.value,
                  intensity: widget.intensity,
                ),
              );
            },
          ),
        ),

        // Foreground content
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _OriginalBlueAiGradientPainter extends CustomPainter {
  final double progress;
  final double intensity;

  _OriginalBlueAiGradientPainter({
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final twoPi = 2 * math.pi;

    // 1. Violet / Indigo Luminous Aura
    final orb1Center = Offset(
      size.width * (0.5 + 0.32 * math.sin(t * twoPi)),
      size.height * (0.35 + 0.22 * math.cos(t * twoPi)),
    );
    final orb1Radius = size.width * (0.65 + 0.08 * math.sin(t * 4 * math.pi));
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6366F1).withValues(alpha: 0.25 * intensity),
          const Color(0xFF8B5CF6).withValues(alpha: 0.15 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: orb1Radius));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), orb1Paint);

    // 2. Cyan / Neon Azure Drifting Spark (The signature blue AI glow)
    final orb2Center = Offset(
      size.width * (0.28 - 0.26 * math.cos(t * twoPi)),
      size.height * (0.68 + 0.18 * math.sin(t * twoPi)),
    );
    final orb2Radius = size.width * (0.72 + 0.12 * math.cos(t * 3 * math.pi));
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF06B6D4).withValues(alpha: 0.28 * intensity),
          const Color(0xFF3B82F6).withValues(alpha: 0.18 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: orb2Radius));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), orb2Paint);

    // 3. Warm Magenta / Rose Bloom (Subtle contrast accent)
    final orb3Center = Offset(
      size.width * (0.72 + 0.20 * math.cos(t * twoPi + 1.4)),
      size.height * (0.72 - 0.22 * math.sin(t * twoPi + 1.4)),
    );
    final orb3Radius = size.width * (0.58 + 0.08 * math.sin(t * twoPi));
    final orb3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFEC4899).withValues(alpha: 0.14 * intensity),
          const Color(0xFF9333EA).withValues(alpha: 0.08 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: orb3Center, radius: orb3Radius));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), orb3Paint);

    // 4. Emerald Accent Core
    final orb4Center = Offset(
      size.width * (0.48 - 0.18 * math.sin(t * twoPi + 2.2)),
      size.height * (0.22 + 0.14 * math.cos(t * twoPi + 2.2)),
    );
    final orb4Radius = size.width * 0.48;
    final orb4Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF10B981).withValues(alpha: 0.12 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: orb4Center, radius: orb4Radius));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), orb4Paint);

    // 5. Cinematic Edge Vignette keeping text & cards ultra-crisp
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.25,
        colors: [
          Colors.transparent,
          AppTheme.background.withValues(alpha: 0.65),
        ],
        stops: const [0.35, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  @override
  bool shouldRepaint(covariant _OriginalBlueAiGradientPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.intensity != intensity;
  }
}
