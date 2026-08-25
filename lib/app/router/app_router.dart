import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
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
      builder: (context, state) => SplashScreen(),
    ),

    // Onboarding
    GoRoute(
      path: RoutePaths.onboarding,
      builder: (context, state) => OnboardingScreen(),
    ),

    // Authentication - Login
    GoRoute(
      path: RoutePaths.login,
      builder: (context, state) => LoginScreen(),
    ),

    // Terms & Privacy
    GoRoute(
      path: RoutePaths.terms,
      builder: (context, state) => TermsScreen(),
    ),

    // Chat - Start (topic selection)
    GoRoute(
      path: RoutePaths.startChat,
      builder: (context, state) => StartChatScreen(),
    ),

    // Chat - Main
    GoRoute(
      path: RoutePaths.chat,
      builder: (context, state) => ChatScreen(),
      routes: [
        // Chat Detail by ID
        GoRoute(
          path: ':chatId',
          builder: (context, state) {
            final chatId = state.pathParameters['chatId'] ?? '';
            return ChatScreen(chatId: chatId);
          },
        ),
      ],
    ),

    // Profile
    GoRoute(
      path: RoutePaths.profile,
      builder: (context, state) => ProfileScreen(),
    ),
  ],

  // Error page
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: Text('Error')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Page not found'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go(RoutePaths.splash),
            child: Text('Go Home'),
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
    print('NavigationObserver: Pushed ${route.settings.name}');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    print('NavigationObserver: Popped ${route.settings.name}');
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    print('NavigationObserver: Removed ${route.settings.name}');
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    print('NavigationObserver: Replaced ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
  }
}
