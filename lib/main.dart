import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/theme.dart';
import 'features/authentication/data/auth_service.dart';
import 'firebase_options.dart';
import 'services/native_notification_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register FCM background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize native notifications (channels, permissions, local notifications)
  await NativeNotificationService.instance.initialize();

  runApp(
    const ProviderScope(
      child: NexoraApp(),
    ),
  );
}

class NexoraApp extends ConsumerWidget {
  const NexoraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Automatically sync FCM device token whenever user is logged in
    ref.listen(authStateProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user != null) {
        final notifService = ref.read(notificationServiceProvider);
        NativeNotificationService.instance.syncDeviceToken(
          notificationService: notifService,
        );
      }
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: NexoraTheme.lightTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      // TODO: Add localization support
      // localizationsDelegates: [
      //   GlobalMaterialLocalizations.delegate,
      //   GlobalWidgetsLocalizations.delegate,
      //   GlobalCupertinoLocalizations.delegate,
      // ],
      // supportedLocales: [
      //   const Locale('en'),
      //   const Locale('hi'),
      // ],
    );
  }
}
