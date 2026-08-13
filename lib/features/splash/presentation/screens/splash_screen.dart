import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';

/// Splash screen - shown during app initialization
class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(NexoraColors.background),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo placeholder
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Color(NexoraColors.primary),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Color(NexoraColors.surface),
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: NexoraSpacing.xl),
            Text(
              'Nexora AI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            SizedBox(height: NexoraSpacing.md),
            Text(
              'College-aware AI Assistant',
              style: TextStyle(
                fontSize: 14,
                color: Color(NexoraColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
