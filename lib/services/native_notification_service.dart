import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/router/app_router.dart';
import 'notification_service.dart';

/// Top-level background message handler for FCM.
///
/// NOTE: Android/FCM handles displaying notification payloads automatically
/// in the system tray when the app is in the background or terminated.
/// We do NOT manually duplicate notifications here to prevent double-alerts.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NativeNotificationService] FCM Background message received: ${message.messageId}');
  if (message.data.isNotEmpty) {
    debugPrint('[NativeNotificationService] FCM Background data: ${message.data}');
  }
}

/// Riverpod provider for NativeNotificationService
final nativeNotificationServiceProvider = Provider<NativeNotificationService>(
  (ref) => NativeNotificationService.instance,
);

class NativeNotificationService {
  NativeNotificationService._();
  static final NativeNotificationService instance = NativeNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  NotificationService? _notificationService;
  String? _currentToken;
  bool _initialized = false;

  // Channel IDs
  static const String channelAcademic = 'nexora_academic_alerts';
  static const String channelMaterials = 'nexora_materials_channel';
  static const String channelEvents = 'nexora_events_channel';
  static const String channelSystem = 'nexora_system_channel';

  /// Getter for current cached FCM token
  String? get currentToken => _currentToken;

  /// Initialize native notification plugins, Android channels, and FCM listeners.
  Future<void> initialize({NotificationService? notificationService}) async {
    if (_initialized) {
      if (notificationService != null) {
        _notificationService = notificationService;
      }
      return;
    }

    _notificationService = notificationService;

    // 1. Initialize Local Notifications for Android/iOS
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[NativeNotificationService] Local notification tapped: ${response.payload}');
        handlePayload(response.payload);
      },
    );

    // 2. Create high-importance Android notification channels
    await _createNotificationChannels();

    // 3. Request permissions on Android 13+ and iOS
    await requestPermissions();

    // 4. Configure FCM Foreground Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[NativeNotificationService] Foreground FCM received: ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // 5. Configure FCM Opened App from Background Listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[NativeNotificationService] FCM onMessageOpenedApp: ${message.messageId}');
      _handleRemoteMessageTap(message);
    });

    // 6. Listen to Token Refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      debugPrint('[NativeNotificationService] FCM Token refreshed: ${newToken.substring(0, newToken.length > 8 ? 8 : newToken.length)}...');
      if (_notificationService != null) {
        _notificationService!.registerDeviceToken(
          fcmToken: newToken,
          platform: _getPlatformString(),
        );
      }
    });

    // 7. Check if app was opened from terminated state by an FCM notification
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NativeNotificationService] App launched from terminated state via FCM: ${initialMessage.messageId}');
        // Allow router to initialize before triggering route
        Future.delayed(const Duration(milliseconds: 600), () {
          _handleRemoteMessageTap(initialMessage);
        });
      }
    } catch (e) {
      debugPrint('[NativeNotificationService] getInitialMessage error: $e');
    }

    _initialized = true;
    debugPrint('[NativeNotificationService] Native Notification Service fully initialized');
  }

  /// Create dedicated Android Notification Channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      return;
    }

    // Academic Channel (High Importance)
    const academicChannel = AndroidNotificationChannel(
      channelAcademic,
      'Academic Announcements',
      description: 'Exam notifications, timetable updates, and official BVC notices',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Materials Channel
    const materialsChannel = AndroidNotificationChannel(
      channelMaterials,
      'Study Materials & Notes',
      description: 'Syllabus, subject materials, and previous question papers',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );

    // Events Channel
    const eventsChannel = AndroidNotificationChannel(
      channelEvents,
      'College Events & Activities',
      description: 'College fests, workshops, and extracurricular announcements',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );

    // System Channel (High Importance)
    const systemChannel = AndroidNotificationChannel(
      channelSystem,
      'System & Security Alerts',
      description: 'Account security, verification alerts, and system notices',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await androidPlugin.createNotificationChannel(academicChannel);
    await androidPlugin.createNotificationChannel(materialsChannel);
    await androidPlugin.createNotificationChannel(eventsChannel);
    await androidPlugin.createNotificationChannel(systemChannel);
  }

  /// Request Notification Permissions (Android 13+ POST_NOTIFICATIONS and iOS)
  Future<bool> requestPermissions() async {
    try {
      // Android 13+ POST_NOTIFICATIONS permission
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('[NativeNotificationService] Android notification permission: $granted');
      }

      // Firebase Messaging permission (iOS / Web)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[NativeNotificationService] FCM authorization status: ${settings.authorizationStatus}');
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('[NativeNotificationService] Permission request error: $e');
      return false;
    }
  }

  /// Syncs the current FCM device token with the authenticated Cloudflare Worker backend
  Future<bool> syncDeviceToken({NotificationService? notificationService}) async {
    if (notificationService != null) {
      _notificationService = notificationService;
    }

    if (_notificationService == null) {
      debugPrint('[NativeNotificationService] Cannot sync device token: NotificationService not set');
      return false;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[NativeNotificationService] FCM token is null or empty');
        return false;
      }

      _currentToken = token;
      final preview = token.length > 8 ? token.substring(0, 8) : token;
      debugPrint('[NativeNotificationService] Syncing FCM token ($preview...) to Cloudflare Worker');

      final success = await _notificationService!.registerDeviceToken(
        fcmToken: token,
        platform: _getPlatformString(),
      );

      debugPrint('[NativeNotificationService] FCM token registration result: $success');
      return success;
    } catch (e) {
      debugPrint('[NativeNotificationService] Error syncing device token: $e');
      return false;
    }
  }

  /// Unregisters the current device's FCM token upon logout.
  /// Preserves other devices owned by the same student.
  Future<bool> unregisterCurrentDevice({NotificationService? notificationService}) async {
    final service = notificationService ?? _notificationService;
    if (service == null) {
      return false;
    }

    try {
      final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        final success = await service.unregisterDeviceToken(token);
        debugPrint('[NativeNotificationService] Unregistered current device token on logout: $success');
        return success;
      }
      return false;
    } catch (e) {
      debugPrint('[NativeNotificationService] Error unregistering current device token: $e');
      return false;
    }
  }

  /// Handles incoming Foreground FCM messages by converting them into native heads-up alerts.
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Nexora Notice';
    final body = notification?.body ?? message.data['body'] ?? 'New notification received';
    final channelId = _selectChannel(message.data['type']);

    final payload = jsonEncode({
      'route': message.data['route'] ?? '/notifications',
      'type': message.data['type'] ?? 'GENERAL',
      'reference_id': message.data['reference_id'] ?? '',
    });

    showLocalNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: payload,
      channelId: channelId,
    );
  }

  /// Handles FCM notification taps (when opened from background or terminated)
  void _handleRemoteMessageTap(RemoteMessage message) {
    final route = message.data['route'] as String?;
    final type = message.data['type'] as String?;

    if (route != null && route.isNotEmpty) {
      handlePayload(jsonEncode({'route': route, 'type': type}));
    } else {
      handlePayload(jsonEncode({'route': '/notifications', 'type': type}));
    }
  }

  /// Notification routing layer to navigate to the correct Nexora screen
  void handlePayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) {
      appRouter.push(RoutePaths.notifications);
      return;
    }

    try {
      final Map<String, dynamic> data;
      if (rawPayload.startsWith('{')) {
        data = jsonDecode(rawPayload) as Map<String, dynamic>;
      } else {
        data = {'route': rawPayload};
      }

      final targetRoute = data['route'] as String? ?? RoutePaths.notifications;

      debugPrint('[NativeNotificationService] Navigating to: $targetRoute');
      appRouter.push(targetRoute);
    } catch (e) {
      debugPrint('[NativeNotificationService] Error parsing notification payload: $e');
      appRouter.push(RoutePaths.notifications);
    }
  }

  /// Shows a local native notification in the device system tray with sound & vibration
  Future<void> showLocalNotification({
    required String title,
    required String body,
    int? id,
    String? payload,
    String channelId = channelAcademic,
  }) async {
    try {
      final notifId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
      debugPrint('[NativeNotificationService] Displayed local native notification: "$title"');
    } catch (e) {
      debugPrint('[NativeNotificationService] Error showing local notification: $e');
    }
  }

  /// Helper to map notification type to channel ID
  String _selectChannel(String? type) {
    switch (type?.toUpperCase()) {
      case 'ACADEMIC_ALERT':
      case 'EXAM':
      case 'ATTENDANCE':
      case 'RESULTS':
        return channelAcademic;
      case 'MATERIAL':
      case 'NOTES':
        return channelMaterials;
      case 'EVENT':
      case 'ACTIVITY':
        return channelEvents;
      case 'SECURITY':
      case 'SYSTEM':
        return channelSystem;
      default:
        return channelAcademic;
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case channelMaterials:
        return 'Study Materials & Notes';
      case channelEvents:
        return 'College Events & Activities';
      case channelSystem:
        return 'System & Security Alerts';
      case channelAcademic:
      default:
        return 'Academic Announcements';
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case channelMaterials:
        return 'Syllabus, study resources, and materials';
      case channelEvents:
        return 'College activities and cultural notices';
      case channelSystem:
        return 'System alerts and security notices';
      case channelAcademic:
      default:
        return 'Official BVC academic updates and notices';
    }
  }

  String _getPlatformString() {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'unknown';
  }
}
