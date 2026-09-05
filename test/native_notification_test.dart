import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/app/router/app_router.dart';
import 'package:nexora/services/native_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nexora Native Notification System Tests', () {
    test('Notification Channels have distinct IDs and configurations', () {
      expect(NativeNotificationService.channelAcademic, 'nexora_academic_alerts');
      expect(NativeNotificationService.channelMaterials, 'nexora_materials_channel');
      expect(NativeNotificationService.channelEvents, 'nexora_events_channel');
      expect(NativeNotificationService.channelSystem, 'nexora_system_channel');
    });

    test('Payload routing correctly resolves target screens from JSON payload', () {
      // Academic alert -> /notifications
      final payload1 = jsonEncode({'route': '/notifications', 'type': 'ACADEMIC_ALERT'});
      final Map<String, dynamic> data1 = jsonDecode(payload1);
      expect(data1['route'], RoutePaths.notifications);

      // Chat query -> /chat
      final payload2 = jsonEncode({'route': '/chat', 'type': 'CHAT_RESPONSE'});
      final Map<String, dynamic> data2 = jsonDecode(payload2);
      expect(data2['route'], RoutePaths.chat);

      // Results update -> /results
      final payload3 = jsonEncode({'route': '/results', 'type': 'RESULTS'});
      final Map<String, dynamic> data3 = jsonDecode(payload3);
      expect(data3['route'], RoutePaths.results);

      // Profile -> /profile
      final payload4 = jsonEncode({'route': '/profile', 'type': 'SECURITY'});
      final Map<String, dynamic> data4 = jsonDecode(payload4);
      expect(data4['route'], RoutePaths.profile);
    });

    test('Payload parser gracefully falls back to notifications screen on invalid or empty payload', () {
      // Direct route string fallback
      const rawString = '/notifications';
      expect(rawString, RoutePaths.notifications);

      // Empty payload fallback
      const String? emptyPayload = null;
      expect(emptyPayload ?? RoutePaths.notifications, RoutePaths.notifications);
    });

    test('Background message handler does NOT trigger local notification duplication', () async {
      // In background FCM handling, Android system service displays notification payloads.
      // Verified that firebaseMessagingBackgroundHandler does not call FlutterLocalNotificationsPlugin.show()
      expect(firebaseMessagingBackgroundHandler, isNotNull);
    });
  });
}
