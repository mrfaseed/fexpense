import 'dart:ui';
import 'package:flutter/material.dart';

/// Apple VisionOS / macOS styled Frosted Glassmorphism card.
/// Translucent smoked glass with backdrop blur, subtle inner specular sheen,
/// and luminous ambient bounce light.
class BorderBeamCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double borderWidth;
  final double beamLengthFraction;
  final Duration duration;

  const BorderBeamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.borderRadius = 24.0,
    this.borderWidth = 1.2,
    this.beamLengthFraction = 0.28,
    this.duration = const Duration(seconds: 5),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Deep drop shadow for depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          // Subtle ambient cyan/blue backlight bounce
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              // Frosted translucent smoke glass gradient
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF13192B).withValues(alpha: 0.65),
                  const Color(0xFF0A0E1A).withValues(alpha: 0.75),
                ],
              ),
              // Sleek translucent glass border with specular highlight
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
