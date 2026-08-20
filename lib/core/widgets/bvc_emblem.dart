import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// BVC College circular seal emblem component matching the Figma artwork
class BvcEmblem extends StatelessWidget {
  final double size;

  const BvcEmblem({
    Key? key,
    this.size = 140,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BvcEmblemPainter(),
      ),
    );
  }
}

class _BvcEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.44);
    final radius = size.width * 0.38;

    // Outer brown ribbon / banner shadow
    final ribbonPaint = Paint()
      ..color = const Color(0xFF6E260E) // Warm deep maroon/brown
      ..style = PaintingStyle.fill;

    // Ribbon path at bottom
    final ribbonPath = Path();
    final ribbonTop = size.height * 0.78;
    final ribbonHeight = size.height * 0.18;
    final ribbonWidth = size.width * 0.75;
    final ribbonLeft = (size.width - ribbonWidth) / 2;

    ribbonPath.moveTo(ribbonLeft, ribbonTop);
    ribbonPath.quadraticBezierTo(
      size.width / 2,
      ribbonTop + 8,
      ribbonLeft + ribbonWidth,
      ribbonTop,
    );
    ribbonPath.lineTo(ribbonLeft + ribbonWidth - 10, ribbonTop + ribbonHeight);
    ribbonPath.quadraticBezierTo(
      size.width / 2,
      ribbonTop + ribbonHeight + 8,
      ribbonLeft + 10,
      ribbonTop + ribbonHeight,
    );
    ribbonPath.close();
    canvas.drawPath(ribbonPath, ribbonPaint);

    // Ribbon tails
    final tailPaint = Paint()
      ..color = const Color(0xFF531A08)
      ..style = PaintingStyle.fill;
    
    // Left tail
    final leftTail = Path()
      ..moveTo(ribbonLeft + 5, ribbonTop + 5)
      ..lineTo(ribbonLeft - 15, ribbonTop + ribbonHeight - 5)
      ..lineTo(ribbonLeft - 5, ribbonTop + ribbonHeight / 2)
      ..lineTo(ribbonLeft + 10, ribbonTop + ribbonHeight)
      ..close();
    canvas.drawPath(leftTail, tailPaint);

    // Right tail
    final rightTail = Path()
      ..moveTo(ribbonLeft + ribbonWidth - 5, ribbonTop + 5)
      ..lineTo(ribbonLeft + ribbonWidth + 15, ribbonTop + ribbonHeight - 5)
      ..lineTo(ribbonLeft + ribbonWidth + 5, ribbonTop + ribbonHeight / 2)
      ..lineTo(ribbonLeft + ribbonWidth - 10, ribbonTop + ribbonHeight)
      ..close();
    canvas.drawPath(rightTail, tailPaint);

    // Outer gold border ring
    final goldBorderPaint = Paint()
      ..color = const Color(0xFFC88A2C) // Rich gold/bronze
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(center, radius, goldBorderPaint);

    // Outer circle fill
    final outerFillPaint = Paint()
      ..color = const Color(0xFFFFFDF8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 2.5, outerFillPaint);

    // Inner ring border
    final innerRingPaint = Paint()
      ..color = const Color(0xFF8B5A2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius * 0.72, innerRingPaint);

    // Center emblem shield fill
    final centerFill = Paint()
      ..color = const Color(0xFFEEF5FA) // Subtle icy blue/white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.70, centerFill);

    // Center college graphics (Temple / Lamp / Book icon)
    final emblemGraphicPaint = Paint()
      ..color = const Color(0xFF8B2500) // Deep crimson
      ..style = PaintingStyle.fill;

    // College tower / lamp shape
    final towerPath = Path();
    final towerW = radius * 0.45;
    final towerH = radius * 0.55;
    final towerLeft = center.dx - towerW / 2;
    final towerTop = center.dy - towerH * 0.45;

    // Central book & flame
    towerPath.moveTo(center.dx, towerTop);
    towerPath.lineTo(towerLeft + towerW, towerTop + towerH * 0.4);
    towerPath.lineTo(towerLeft + towerW * 0.8, towerTop + towerH);
    towerPath.lineTo(towerLeft + towerW * 0.2, towerTop + towerH);
    towerPath.lineTo(towerLeft, towerTop + towerH * 0.4);
    towerPath.close();
    canvas.drawPath(towerPath, emblemGraphicPaint);

    // Flame on top of lamp
    final flamePaint = Paint()
      ..color = const Color(0xFFFFA500)
      ..style = PaintingStyle.fill;
    final flamePath = Path()
      ..moveTo(center.dx, towerTop - 12)
      ..quadraticBezierTo(center.dx + 6, towerTop - 5, center.dx, towerTop)
      ..quadraticBezierTo(center.dx - 6, towerTop - 5, center.dx, towerTop - 12)
      ..close();
    canvas.drawPath(flamePath, flamePaint);

    // Inner details (white lines in book)
    final detailPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(center.dx, towerTop + 8),
      Offset(center.dx, towerTop + towerH - 4),
      detailPaint,
    );

    // Decorative ring dots
    final dotPaint = Paint()
      ..color = const Color(0xFFC88A2C)
      ..style = PaintingStyle.fill;
    const dotCount = 18;
    for (int i = 0; i < dotCount; i++) {
      final angle = (i * 2 * math.pi) / dotCount;
      final dotX = center.dx + (radius * 0.86) * math.cos(angle);
      final dotY = center.dy + (radius * 0.86) * math.sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), 1.6, dotPaint);
    }

    // Text on ribbon: "ESTD 1997" or "BVC"
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'BVC ENGINEERING',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, ribbonTop + 5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
