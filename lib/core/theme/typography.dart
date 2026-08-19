import 'package:flutter/material.dart';
import 'colors.dart';

/// Nexora typography system
class NexoraTypography {
  NexoraTypography._();

  // Heading Styles
  static const TextStyle heading1 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 32,
    fontWeight: FontWeight.bold, // 700
    height: 1.2,
    color: Color(NexoraColors.text),
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.bold, // 700
    height: 1.2,
    color: Color(NexoraColors.text),
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 24,
    fontWeight: FontWeight.bold, // 700
    height: 1.3,
    color: Color(NexoraColors.text),
  );

  static const TextStyle heading4 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20,
    fontWeight: FontWeight.bold, // 700
    height: 1.3,
    color: Color(NexoraColors.text),
  );

  // Body Styles
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
    fontWeight: FontWeight.w500, // 500 (Medium)
    height: 1.5,
    color: Color(NexoraColors.text),
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w400, // 400 (Regular)
    height: 1.5,
    color: Color(NexoraColors.text),
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400, // 400 (Regular)
    height: 1.5,
    color: Color(NexoraColors.textSecondary),
  );

  // Label Styles
  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600, // 600 (Semi-bold)
    height: 1.4,
    color: Color(NexoraColors.text),
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w600, // 600 (Semi-bold)
    height: 1.4,
    color: Color(NexoraColors.text),
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w600, // 600 (Semi-bold)
    height: 1.3,
    color: Color(NexoraColors.textMuted),
  );

  // Display Styles
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 40,
    fontWeight: FontWeight.bold, // 700
    height: 1.2,
    color: Color(NexoraColors.text),
  );

  // Button Text
  static const TextStyle button = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600, // 600 (Semi-bold)
    height: 1.5,
    color: Color(NexoraColors.surface),
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w600, // 600 (Semi-bold)
    height: 1.4,
    color: Color(NexoraColors.surface),
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w400, // 400 (Regular)
    height: 1.4,
    color: Color(NexoraColors.textMuted),
  );
}
