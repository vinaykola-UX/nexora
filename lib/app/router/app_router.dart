import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/signup_screen.dart';
import '../../features/authentication/presentation/screens/verify_email_screen.dart';
import '../../features/profile/presentation/screens/class_setup_screen.dart';
import '../../features/terms/presentation/screens/terms_screen.dart';
import '../../features/chat/presentation/screens/start_chat_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';

/// Route paths
class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verifyEmail = '/verify-email';
  static const String classSetup = '/class-setup';
  static const String terms = '/terms';
  static const String startChat = '/start-chat';
  static const String chat = '/chat';
  static const String chatDetail = '/chat/:chatId';
  static const String profile = '/profile';
}

/// Global router configuration
final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.splash,
  routes: [
    // Splash Screen
    GoRoute(
      path: RoutePaths.splash,
      builder: (context, state) => const SplashScreen(),
    ),

    // Onboarding
    GoRoute(
      path: RoutePaths.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Authentication - Login
    GoRoute(
      path: RoutePaths.login,
      builder: (context, state) => const LoginScreen(),
    ),

    // Authentication - Sign Up
    GoRoute(
      path: RoutePaths.signup,
      builder: (context, state) => const SignupScreen(),
    ),

    // Authentication - Verify Email
    GoRoute(
      path: RoutePaths.verifyEmail,
      builder: (context, state) {
        final email = state.extra as String? ?? '';
        return VerifyEmailScreen(email: email);
      },
    ),

    // Student Onboarding - One-Time Class & Section Setup
    GoRoute(
      path: RoutePaths.classSetup,
      builder: (context, state) => const ClassSetupScreen(),
    ),

    // Terms & Privacy
    GoRoute(
      path: RoutePaths.terms,
      builder: (context, state) => const TermsScreen(),
    ),

    // Chat - Start (topic selection)
    GoRoute(
      path: RoutePaths.startChat,
      builder: (context, state) => const StartChatScreen(),
    ),

    // Chat - Main
    GoRoute(
      path: RoutePaths.chat,
      builder: (context, state) {
        final initialPrompt = state.extra as String?;
        return ChatScreen(initialPrompt: initialPrompt);
      },
      routes: [
        // Chat Detail by ID
        GoRoute(
          path: ':chatId',
          builder: (context, state) {
            final chatId = state.pathParameters['chatId'] ?? '';
            final initialPrompt = state.extra as String?;
            return ChatScreen(chatId: chatId, initialPrompt: initialPrompt);
          },
        ),
      ],
    ),

    // Profile
    GoRoute(
      path: RoutePaths.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
  ],

  // Error page
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Error')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Page not found'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go(RoutePaths.splash),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),

  // Navigation observers for logging
  observers: [
    NavigationObserver(),
  ],
);

/// Navigation observer for debugging
class NavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint('NavigationObserver: Pushed ${route.settings.name}');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint('NavigationObserver: Popped ${route.settings.name}');
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    debugPrint('NavigationObserver: Removed ${route.settings.name}');
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    debugPrint('NavigationObserver: Replaced ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
  }
}
