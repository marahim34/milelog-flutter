import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Speedometer icon — GoOdo logo. Background #1A0F14, accent #FF5C8A.
/// Replicates the SVG viewBox 0 0 96 96 exactly, scaled to [size].
class GoOdoLogo extends StatelessWidget {
  const GoOdoLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SpeedometerPainter()),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const s = 96.0;
    final sc = size.width / s;

    // Rounded background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.width * 0.225),
      ),
      Paint()..color = const Color(0xFF1A0F14),
    );

    // Subtle glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.width * 0.225),
      ),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.2),
          radius: 0.7,
          colors: [
            const Color(0xFFFF5C8A).withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Arc: M18 62 A30 30 0 0 1 78 62 — half-circle through the top
    canvas.drawArc(
      Rect.fromCircle(center: Offset(48 * sc, 62 * sc), radius: 30 * sc),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFFF5C8A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * sc
        ..strokeCap = StrokeCap.round,
    );

    // Top tick
    canvas.drawLine(
      Offset(48 * sc, 32 * sc),
      Offset(48 * sc, 25 * sc),
      Paint()
        ..color = const Color(0xFFFF5C8A).withValues(alpha: 0.45)
        ..strokeWidth = 2.5 * sc
        ..strokeCap = StrokeCap.round,
    );

    // Needle: (48,62) → (66,38)
    canvas.drawLine(
      Offset(48 * sc, 62 * sc),
      Offset(66 * sc, 38 * sc),
      Paint()
        ..color = const Color(0xFFFF5C8A)
        ..strokeWidth = 3.5 * sc
        ..strokeCap = StrokeCap.round,
    );

    // Pivot outer
    canvas.drawCircle(
      Offset(48 * sc, 62 * sc),
      6 * sc,
      Paint()..color = const Color(0xFFFF5C8A),
    );
    // Pivot inner (dark)
    canvas.drawCircle(
      Offset(48 * sc, 62 * sc),
      3 * sc,
      Paint()..color = const Color(0xFF1A0F14),
    );
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) => false;
}
