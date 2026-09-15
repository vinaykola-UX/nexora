import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:nexora/core/widgets/read_aloud_button.dart';
import 'package:nexora/services/text_to_speech_service.dart';

/// Test-only fake TTS engine strictly for automated widget tests.
class FakeFlutterTts extends FlutterTts {
  VoidCallback? startHandler;
  VoidCallback? pauseHandler;
  dynamic Function(dynamic)? errorHandler;

  int speakCallCount = 0;
  int pauseCallCount = 0;

  @override
  void setStartHandler(VoidCallback callback) {
    startHandler = callback;
  }

  @override
  void setCompletionHandler(VoidCallback callback) {}

  @override
  void setPauseHandler(VoidCallback callback) {
    pauseHandler = callback;
  }

  @override
  void setContinueHandler(VoidCallback callback) {}

  @override
  void setErrorHandler(dynamic Function(dynamic) callback) {
    errorHandler = callback;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    speakCallCount++;
    startHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> pause() async {
    pauseCallCount++;
    pauseHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterTts fakeTts;
  late TextToSpeechService ttsService;

  setUp(() {
    fakeTts = FakeFlutterTts();
    ttsService = TextToSpeechService(tts: fakeTts);
  });

  tearDown(() {
    ttsService.dispose();
  });

  group('ReadAloudButton Widget Tests', () {
    testWidgets('1. Renders idle state with volume up icon and "Read" label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadAloudButton(
              messageId: 'msg_1',
              text: 'AVL trees are height-balanced binary search trees.',
              ttsService: ttsService,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
    });

    testWidgets('2. Renders disabled/muted state when enabled is false (streaming)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadAloudButton(
              messageId: 'msg_stream',
              text: 'Streaming answer...',
              ttsService: ttsService,
              enabled: false,
            ),
          ),
        ),
      );

      // Tap should do nothing
      await tester.tap(find.byType(ReadAloudButton));
      await tester.pump();

      expect(fakeTts.speakCallCount, equals(0));
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('3. Tapping idle button triggers ttsService.speak', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadAloudButton(
              messageId: 'msg_2',
              text: 'Artificial Intelligence in education.',
              ttsService: ttsService,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ReadAloudButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(fakeTts.speakCallCount, equals(1));
    });

    testWidgets('4. Renders playing state with pause icon, tapping calls pause', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadAloudButton(
              messageId: 'msg_3',
              text: 'Playing test message.',
              ttsService: ttsService,
            ),
          ),
        ),
      );

      // Start playing
      await ttsService.speak('msg_3', 'Playing test message.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);

      // Tap to pause
      await tester.tap(find.byType(ReadAloudButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(fakeTts.pauseCallCount, equals(1));
    });

    testWidgets('5. Renders paused state with play arrow, tapping resumes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadAloudButton(
              messageId: 'msg_4',
              text: 'Resuming test message.',
              ttsService: ttsService,
            ),
          ),
        ),
      );

      // Start then pause
      await ttsService.speak('msg_4', 'Resuming test message.');
      await ttsService.pause();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      // Tap to resume
      await tester.tap(find.byType(ReadAloudButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(ttsService.currentState.isPlaying, isTrue);
    });
  });
}
