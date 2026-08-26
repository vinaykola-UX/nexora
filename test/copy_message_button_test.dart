import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/widgets/copy_message_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CopyMessageButton Widget Tests', () {
    testWidgets('Renders idle state with copy icon and label', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CopyMessageButton(
              text: 'This is a test response from Nexora.',
            ),
          ),
        ),
      );

      expect(find.text('Copy'), findsOneWidget);
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      expect(find.text('Copied'), findsNothing);
    });

    testWidgets('Tapping Copy transitions to Copied state and resets after delay', (WidgetTester tester) async {
      String? copiedClipboardText;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            copiedClipboardText = args['text'] as String?;
            return null;
          }
          return null;
        },
      );

      const testContent = 'B.Tech supplementary exams start next month.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CopyMessageButton(
              text: testContent,
            ),
          ),
        ),
      );

      // Tap Copy button
      await tester.tap(find.byType(CopyMessageButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(copiedClipboardText, equals(testContent));
      expect(find.text('Copied'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Advance time beyond 2000ms
      await tester.pump(const Duration(milliseconds: 2100));

      expect(find.text('Copy'), findsOneWidget);
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    });

    testWidgets('Multiple buttons track per-message state independently', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CopyMessageButton(key: Key('btn1'), text: 'Response 1'),
                CopyMessageButton(key: Key('btn2'), text: 'Response 2'),
              ],
            ),
          ),
        ),
      );

      // Tap only button 1
      await tester.tap(find.byKey(const Key('btn1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Button 1 shows Copied, Button 2 still shows Copy
      expect(find.text('Copied'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('Disposing widget before reset timer completes does not crash', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CopyMessageButton(
              text: 'Transient message',
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CopyMessageButton));
      await tester.pump();

      // Replace widget before 2s timer completes (simulating user navigating away)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Advance time — no exception thrown
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(CopyMessageButton), findsNothing);
    });
  });
}
