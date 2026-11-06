import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../core/widgets/bvc_emblem.dart';
import '../../../../app/router/app_router.dart';

/// Onboarding screen matching Figma Mobile UI
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  void _onGetStarted(BuildContext context) {
    context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(NexoraColors.background),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: NexoraSpacing.xl,
            vertical: NexoraSpacing.lg,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: NexoraSpacing.md),

              // Centered Card with Emblem & Branding
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Large Rounded White Card with BVC College Seal
                  Container(
                    width: size.width * 0.78,
                    height: size.width * 0.78,
                    constraints: const BoxConstraints(
                      maxWidth: 320,
                      maxHeight: 320,
                      minWidth: 220,
                      minHeight: 220,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(NexoraColors.surface),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(NexoraColors.border).withOpacity(0.7),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: BvcEmblem(size: 170),
                    ),
                  ),
                  const SizedBox(height: NexoraSpacing.xxl),

                  // Title
                  const Text(
                    'Nexora AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(NexoraColors.text),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: NexoraSpacing.md),

                  // Subtitle description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: NexoraSpacing.md),
                    child: const Text(
                      'Welcome to Nexora college-aware app,\nyour all in one college AI assistant',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(NexoraColors.textSecondary),
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom Button: "Get Started" Black Pill Button
              Padding(
                padding: const EdgeInsets.only(bottom: NexoraSpacing.md),
                child: NexoraButton(
                  label: 'Get Started',
                  onPressed: () => _onGetStarted(context),
                  width: double.infinity,
                  height: 54,
                  backgroundColor: const Color(0xFF171717),
                  foregroundColor: Colors.white,
                  borderRadius: 100,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
