import 'package:flutter/material.dart';
import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Nexora app theme configuration
class NexoraTheme {
  NexoraTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Color Scheme
      colorScheme: ColorScheme.light(
        primary: Color(NexoraColors.primary),
        onPrimary: Color(NexoraColors.surface),
        secondary: Color(NexoraColors.primaryLight),
        onSecondary: Color(NexoraColors.text),
        tertiary: Color(NexoraColors.primaryDark),
        error: Color(NexoraColors.error),
        onError: Color(NexoraColors.surface),
        surface: Color(NexoraColors.surface),
        onSurface: Color(NexoraColors.text),
        outline: Color(NexoraColors.border),
      ),
      // Scaffold
      scaffoldBackgroundColor: Color(NexoraColors.background),
      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: Color(NexoraColors.surface),
        foregroundColor: Color(NexoraColors.text),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: NexoraTypography.heading4.copyWith(
          color: Color(NexoraColors.text),
        ),
      ),
      // Text Styles
      textTheme: TextTheme(
        displayLarge: NexoraTypography.displayLarge,
        displayMedium: NexoraTypography.heading1,
        displaySmall: NexoraTypography.heading2,
        headlineMedium: NexoraTypography.heading3,
        headlineSmall: NexoraTypography.heading4,
        titleLarge: NexoraTypography.labelLarge,
        titleMedium: NexoraTypography.labelMedium,
        titleSmall: NexoraTypography.labelSmall,
        bodyLarge: NexoraTypography.bodyLarge,
        bodyMedium: NexoraTypography.bodyMedium,
        bodySmall: NexoraTypography.bodySmall,
        labelLarge: NexoraTypography.button,
        labelMedium: NexoraTypography.labelMedium,
        labelSmall: NexoraTypography.caption,
      ),
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(NexoraColors.primary),
          foregroundColor: Color(NexoraColors.surface),
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: NexoraSpacing.lg,
            vertical: NexoraSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
          ),
          textStyle: NexoraTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Color(NexoraColors.primary),
          side: BorderSide(
            color: Color(NexoraColors.primary),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: NexoraSpacing.lg,
            vertical: NexoraSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
          ),
          textStyle: NexoraTypography.button.copyWith(
            color: Color(NexoraColors.primary),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Color(NexoraColors.primary),
          padding: EdgeInsets.symmetric(
            horizontal: NexoraSpacing.lg,
            vertical: NexoraSpacing.md,
          ),
          textStyle: NexoraTypography.button.copyWith(
            color: Color(NexoraColors.primary),
          ),
        ),
      ),
      // Text Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(NexoraColors.inputBackground),
        contentPadding: EdgeInsets.symmetric(
          horizontal: NexoraSpacing.lg,
          vertical: NexoraSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
          borderSide: BorderSide(
            color: Color(NexoraColors.border),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
          borderSide: BorderSide(
            color: Color(NexoraColors.border),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
          borderSide: BorderSide(
            color: Color(NexoraColors.primary),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
          borderSide: BorderSide(
            color: Color(NexoraColors.error),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
          borderSide: BorderSide(
            color: Color(NexoraColors.error),
            width: 2,
          ),
        ),
        hintStyle: NexoraTypography.bodyMedium.copyWith(
          color: Color(NexoraColors.textMuted),
        ),
        labelStyle: NexoraTypography.labelMedium.copyWith(
          color: Color(NexoraColors.textSecondary),
        ),
      ),
      // Card
      cardTheme: CardThemeData(
        color: Color(NexoraColors.surface),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexoraSpacing.radiusLG),
          side: BorderSide(
            color: Color(NexoraColors.border),
          ),
        ),
      ),
      // Divider
      dividerTheme: DividerThemeData(
        color: Color(NexoraColors.divider),
        thickness: 1,
        space: NexoraSpacing.lg,
      ),
      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Color(NexoraColors.surface),
        selectedItemColor: Color(NexoraColors.primary),
        unselectedItemColor: Color(NexoraColors.textMuted),
        type: BottomNavigationBarType.fixed,
      ),
      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: Color(NexoraColors.surface),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexoraSpacing.radiusXL),
        ),
      ),
      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Color(NexoraColors.surface),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(NexoraSpacing.radiusXL),
            topRight: Radius.circular(NexoraSpacing.radiusXL),
          ),
        ),
      ),
      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Color(NexoraColors.primary),
        foregroundColor: Color(NexoraColors.surface),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexoraSpacing.radiusCircle),
        ),
      ),
    );
  }
}
