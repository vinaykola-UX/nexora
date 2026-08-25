import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Nexora "N" sparkle icon matching the Figma branding mark
class NexoraSparkleIcon extends StatelessWidget {
  final double size;
  final double borderRadius;

  const NexoraSparkleIcon({
    Key? key,
    this.size = 72,
    this.borderRadius = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(NexoraColors.surface),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(NexoraColors.border).withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.65,
          height: size * 0.65,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // "N" Mark in center
              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF1E1E1E), // Dark rich black
                      Color(0xFF8B4513), // Saddle brown/dark orange
                      Color(0xFFFFA500), // Vibrant orange accent
                    ],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ).createShader(bounds),
                  child: Text(
                    'N',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: size * 0.46,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),

              // Sparkle / 4-point star in top-right
              Positioned(
                top: 0,
                right: 0,
                child: CustomPaint(
                  size: Size(size * 0.24, size * 0.24),
                  painter: _SparklePainter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFFFA500)
      ..style = PaintingStyle.fill;

    final path = Path();
    final r = size.width / 2;
    final innerR = r * 0.22;

    for (int i = 0; i < 4; i++) {
      final outerAngle = (i * math.pi / 2);
      final innerAngle = outerAngle + (math.pi / 4);

      if (i == 0) {
        path.moveTo(
          center.dx + r * math.cos(outerAngle),
          center.dy + r * math.sin(outerAngle),
        );
      } else {
        path.lineTo(
          center.dx + r * math.cos(outerAngle),
          center.dy + r * math.sin(outerAngle),
        );
      }

      path.lineTo(
        center.dx + innerR * math.cos(innerAngle),
        center.dy + innerR * math.sin(innerAngle),
      );
    }
    path.close();
    canvas.drawPath(path, paint);

    // Inner bright center dot
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerR * 0.6, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
