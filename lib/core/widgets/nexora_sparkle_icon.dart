import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Nexora "N" sparkle icon displaying the official Nexora app logo
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
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/nexora_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(NexoraColors.surface),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome, color: Color(0xFFC85A32)),
              ),
            );
          },
        ),
      ),
    );
  }
}
