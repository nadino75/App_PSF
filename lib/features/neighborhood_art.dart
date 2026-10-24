import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/visual_theme.dart';

/// Resolution-independent artwork: no external images or network dependencies.
class NeighborhoodArt extends StatelessWidget {
  const NeighborhoodArt({super.key, this.variant = 0});
  final int variant;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _NeighborhoodPainter(variant),
      child: const SizedBox.expand(),
    ),
  );
}

class _NeighborhoodPainter extends CustomPainter {
  const _NeighborhoodPainter(this.variant);
  final int variant;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 480, size.height / 320);
    final paint = Paint()..isAntiAlias = true;
    void rect(
      double x,
      double y,
      double w,
      double h,
      Color color, [
      double radius = 0,
    ]) {
      paint.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(radius),
        ),
        paint,
      );
    }

    void circle(double x, double y, double radius, Color color) {
      canvas.drawCircle(Offset(x, y), radius, paint..color = color);
    }

    void stroke(Offset a, Offset b, Color color, double width) {
      canvas.drawLine(
        a,
        b,
        paint
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    void label(
      String value,
      double x,
      double y,
      double w,
      Color color,
      double fontSize,
    ) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            letterSpacing: 2,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: w);
      text.paint(canvas, Offset(x + (w - text.width) / 2, y));
    }

    final sky = [
      const Color(0xFFECECDD),
      const Color(0xFFF2E4D4),
      const Color(0xFFE5EBDD),
    ][variant % 3];
    rect(0, 0, 480, 320, sky);
    circle(370, 69, 39, honey);
    final mountain = Path()
      ..moveTo(0, 172)
      ..lineTo(93, 78)
      ..lineTo(163, 144)
      ..lineTo(239, 60)
      ..lineTo(371, 168)
      ..lineTo(480, 100)
      ..lineTo(480, 264)
      ..lineTo(0, 264)
      ..close();
    canvas.drawPath(mountain, paint..color = const Color(0xFFD6DDCB));
    final ridge = Path()
      ..moveTo(201, 98)
      ..lineTo(239, 60)
      ..lineTo(279, 93)
      ..lineTo(255, 85)
      ..lineTo(241, 95)
      ..lineTo(229, 83)
      ..close();
    canvas.drawPath(ridge, paint..color = paper);
    rect(0, 274, 480, 46, const Color(0xFFCED6C3));
    rect(0, 286, 480, 34, const Color(0xFFE0D4BE));
    // Main local shop with a striped awning and an arched window.
    rect(133, 123, 210, 157, const Color(0xFFF8F2E5), 4);
    rect(126, 116, 224, 12, clay, 3);
    rect(144, 135, 188, 34, forest, 3);
    label(
      variant == 1
          ? 'TALLER LOCAL'
          : variant == 2
          ? 'DE TU BARRIO'
          : 'CAFÉ LOCAL',
      144,
      143,
      188,
      paper,
      14,
    );
    rect(145, 211, 61, 69, const Color(0xFF6D8D75), 3);
    rect(154, 220, 43, 45, const Color(0xFFB9CEB5), 2);
    circle(198, 263, 2.5, honey);
    rect(220, 209, 98, 54, forest, 24);
    rect(225, 215, 88, 43, const Color(0xFFA8C0A6), 20);
    stroke(const Offset(269, 214), const Offset(269, 259), paper, 4);
    rect(214, 263, 110, 7, clay, 2);
    for (var i = 0; i < 10; i++) {
      final x = 133.0 + i * 21;
      final awning = Path()
        ..moveTo(x, 177)
        ..lineTo(x + 21, 177)
        ..lineTo(x + 25, 201)
        ..lineTo(x - 4, 201)
        ..close();
      canvas.drawPath(
        awning,
        paint..color = i.isEven ? clay : const Color(0xFFF1D8AB),
      );
      rect(x - 4, 201, 29, 11, i.isEven ? clay : const Color(0xFFF1D8AB), 5);
    }
    // Neighboring artisan building.
    rect(38, 167, 87, 113, const Color(0xFFD7AB83), 4);
    rect(33, 161, 97, 10, const Color(0xFF935840), 3);
    rect(50, 188, 61, 44, const Color(0xFF557563), 22);
    stroke(const Offset(80, 188), const Offset(80, 232), paper, 3);
    rect(62, 247, 37, 33, forest, 3);
    // Trees, potted plants, paving, and a café sign.
    stroke(const Offset(385, 172), const Offset(385, 279), forest, 7);
    circle(386, 156, 33, const Color(0xFF567B54));
    circle(362, 174, 25, const Color(0xFF719064));
    circle(410, 178, 27, const Color(0xFF426948));
    rect(361, 271, 50, 11, const Color(0xFF9EAA85), 4);
    rect(112, 258, 18, 24, clay, 3);
    for (var i = 0; i < 5; i++) {
      final angle = i * .65 + .25;
      stroke(
        const Offset(121, 260),
        Offset(121 + math.cos(angle) * 16, 240 - math.sin(angle) * 16),
        forest,
        5,
      );
    }
    rect(300, 254, 29, 40, forest, 3);
    rect(304, 258, 21, 25, const Color(0xFFEBDBC0), 2);
    stroke(const Offset(311, 265), const Offset(319, 265), clay, 2);
    stroke(const Offset(309, 271), const Offset(321, 271), clay, 2);
    for (var i = 0; i < 6; i++) {
      stroke(
        Offset(82 + i * 62, 305),
        Offset(107 + i * 62, 305),
        const Color(0xFFC8B99F),
        2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NeighborhoodPainter oldDelegate) =>
      oldDelegate.variant != variant;
}
