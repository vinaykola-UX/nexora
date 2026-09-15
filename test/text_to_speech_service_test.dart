import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:nexora/services/text_to_speech_service.dart';

/// Test-only fake TTS engine strictly for automated tests.
class FakeFlutterTts extends FlutterTts {
  VoidCallback? startHandler;
  VoidCallback? completionHandler;
  VoidCallback? pauseHandler;
  VoidCallback? continueHandler;
  dynamic Function(dynamic)? errorHandler;

  String? lastSpokenText;
  int speakCallCount = 0;
  int pauseCallCount = 0;
  int stopCallCount = 0;

  @override
  void setStartHandler(VoidCallback callback) {
    startHandler = callback;
  }

  @override
  void setCompletionHandler(VoidCallback callback) {
    completionHandler = callback;
  }

  @override
  void setPauseHandler(VoidCallback callback) {
    pauseHandler = callback;
  }

  @override
  void setContinueHandler(VoidCallback callback) {
    continueHandler = callback;
  }

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
    lastSpokenText = text;
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
  Future<dynamic> stop() async {
    stopCallCount++;
    return 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextToSpeechService - Markdown Cleaning', () {
    test('1. Removes markdown headers from speech text', () {
      const input = '''
# Main Header
## Sub Header
### Section 3
Regular paragraph text here.
''';
      final result = TextToSpeechService.cleanMarkdownForSpeech(input);
      expect(result.contains('#'), isFalse);
      expect(result, contains('Main Header'));
      expect(result, contains('Sub Header'));
      expect(result, contains('Section 3'));
      expect(result, contains('Regular paragraph text here.'));
    });

    test('2. Replaces fenced code blocks with "Here is a code example."', () {
      const input = '''
To define a function in Python:

```python
def add(a, b):
    return a + b
```

This returns the sum.
''';
      final result = TextToSpeechService.cleanMarkdownForSpeech(input);
      expect(result.contains('def add'), isFalse);
      expect(result.contains('return a + b'), isFalse);
      expect(result, contains('Here is a code example.'));
      expect(result, contains('This returns the sum.'));
    });

    test('3. Unwraps inline code back into readable plain text', () {
      const input = 'Use the `BinarySearchTree` class with `insert()` method.';
      final result = TextToSpeechService.cleanMarkdownForSpeech(input);
      expect(result.contains('`'), isFalse);
      expect(result, equals('Use the BinarySearchTree class with insert() method.'));
    });

    test('4. Removes bold, italic, and strikethrough markdown symbols', () {
      const input = 'This is **bold** text, *italic* word, and ~~cancelled~~ info.';
      final result = TextToSpeechService.cleanMarkdownForSpeech(input);
      expect(result.contains('**'), isFalse);
      expect(result.contains('*'), isFalse);
      expect(result.contains('~~'), isFalse);
      expect(result, equals('This is bold text, italic word, and cancelled info.'));
    });

    test('5. Strips markdown links and preserves the link title', () {
      const input = 'Check the [BVC Academic Syllabus](https://bvc.edu.in/syllabus) for details.';
      final result = TextToSpeechService.cleanMarkdownForSpeech(input);
      expect(result.contains('https://'), isFalse);
      expect(result.contains('['), isFalse);
      expect(result.contains(']'), isFalse);
      expect(result, equals('Check the BVC Academic Syllabus for details.'));
    });

    test('6. Strips images and HTML markup tags', () {
      const input = '![Campus](/images/campus.png) <br><div class="notice">Exam starts on Monday.</div>';
      final result = TextToSpeechService.cleanMarkdownForSpeech(input);
      expect(result.contains('/images/campus.png'), isFalse);
      expect(result.contains('<br>'), isFalse);
      expect(result.contains('<div>'), isFalse);
      expect(result, equals('Exam starts on Monday.'));
    });

    test('7. Strips bullet list prefixes and blockquotes', () {
      const input = '''
> Important Notice
- First point
* Second point
+ Third point
''';
      final result = TextToSpeechService.cleanMarkdownForSpeech(input);
      expect(result.contains('>'), isFalse);
      expect(result, contains('Important Notice'));
      expect(result, contains('First point'));
      expect(result, contains('Second point'));
      expect(result, contains('Third point'));
    });

    test('8. Handles mathematical formulas and cleans table divider syntax', () {
      const input = '''
| Subject | Credits |
|---|---|
| Mathematics | 4 |

Formula: \$\$E = mc^2\$\$ and inline \$x = 5\$.
''';
      final result = TextToSpeechService.cleanMarkdownForSpeech(input);
      expect(result.contains('|---|---|'), isFalse);
      expect(result.contains(r'$$'), isFalse);
      expect(result, contains('Mathematics'));
      expect(result, contains('formula'));
      expect(result, contains('x = 5'));
    });
  });

  group('TextToSpeechService - Text Chunking', () {
    test('9. Keeps short text as a single chunk', () {
      const text = 'Short response from assistant.';
      final chunks = TextToSpeechService.chunkTextForSpeech(text, maxChunkSize: 100);
      expect(chunks.length, equals(1));
      expect(chunks.first, equals(text));
    });

    test('10. Breaks long text across paragraphs and sentence boundaries', () {
      final p1 = 'A' * 60;
      final p2 = 'B' * 60;
      final longText = '$p1.\n\n$p2.';
      final chunks = TextToSpeechService.chunkTextForSpeech(longText, maxChunkSize: 80);
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(80));
      }
    });
  });

  group('TextToSpeechService - Playback & Single Stream Enforcement', () {
    test('11. Lifecycle states and single playback enforcement across messages', () async {
      final fakeTts = FakeFlutterTts();
      final service = TextToSpeechService(tts: fakeTts);

      expect(service.currentState.isIdle, isTrue);

      // Start playback for Message A
      await service.speak('msg_A', 'Response A text content.');
      expect(service.currentState.isMessagePlaying('msg_A'), isTrue);
      expect(fakeTts.speakCallCount, equals(1));

      // Pause Message A
      await service.pause();
      expect(service.currentState.isMessagePaused('msg_A'), isTrue);
      expect(fakeTts.pauseCallCount, equals(1));

      // Resume Message A
      await service.resume();
      expect(service.currentState.isMessagePlaying('msg_A'), isTrue);

      // Start playback for Message B while Message A is playing
      // Single playback enforcement: Message A must be stopped before Message B starts
      await service.speak('msg_B', 'Response B text content.');
      expect(fakeTts.stopCallCount, greaterThanOrEqualTo(1));
      expect(service.currentState.isMessagePlaying('msg_B'), isTrue);
      expect(service.currentState.isMessageActive('msg_A'), isFalse);

      // Stop Message B
      await service.stop();
      expect(service.currentState.isIdle, isTrue);

      // Cleanup
      service.dispose();
    });
  });
}
