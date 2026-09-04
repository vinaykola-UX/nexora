import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_sparkle_icon.dart';
import '../../../authentication/data/auth_service.dart';
import '../../../profile/data/student_profile_repository.dart';

/// Splash screen - shown only during Firebase initialization.
/// Navigates as soon as auth state is known — no artificial delays.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();
  final StudentProfileRepository _profileRepository =
      StudentProfileRepository();

  @override
  void initState() {
    super.initState();

    // Short logo entry animation (600ms) — no blocking delay
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Navigate as soon as auth check is done — no arbitrary wait
    _navigateNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    // Only wait for the minimal animation so the logo is visible briefly
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final user = _authService.currentUser;

    // Not logged in → onboarding/login
    if (user == null || !_authService.isAuthenticatedAndValid || !user.emailVerified) {
      if (mounted) context.go(RoutePaths.onboarding);
      return;
    }

    // Logged in → check profile completion (non-blocking Firestore read)
    try {
      final isComplete = await _profileRepository.isProfileComplete(user.uid);
      if (!mounted) return;

      if (isComplete) {
        context.go(RoutePaths.startChat);
      } else {
        context.go(RoutePaths.classSetup);
      }
    } catch (_) {
      // On Firestore error, send to main screen and let the app handle gracefully
      if (mounted) context.go(RoutePaths.startChat);
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


