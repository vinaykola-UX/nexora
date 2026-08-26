import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_sparkle_icon.dart';
import '../../../authentication/data/auth_service.dart';
import '../../../profile/data/student_profile_repository.dart';

/// Splash screen - shown during app initialization
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final AuthService _authService = AuthService();
  final StudentProfileRepository _profileRepository = StudentProfileRepository();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _navigateNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final user = _authService.currentUser;
    if (user != null && _authService.isAuthenticatedAndValid && user.emailVerified) {
      try {
        final isComplete = await _profileRepository.isProfileComplete(user.uid);
        if (!mounted) return;

        if (isComplete) {
          context.go(RoutePaths.startChat);
        } else {
          context.go(RoutePaths.classSetup);
        }
      } catch (_) {
        if (mounted) context.go(RoutePaths.startChat);
      }
    } else {
      context.go(RoutePaths.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(NexoraColors.background),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Nexora Sparkle Logo
                const NexoraSparkleIcon(size: 110, borderRadius: 28),
                const SizedBox(height: NexoraSpacing.xxl),

                // App Name
                const Text(
                  'Nexora AI',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(NexoraColors.text),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: NexoraSpacing.sm),

                // Tagline
                const Text(
                  'College-aware AI Assistant',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(NexoraColors.textSecondary),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
