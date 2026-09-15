import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Represents the playback state of the Text-to-Speech engine.
enum TtsState {
  idle,
  playing,
  paused,
}

/// Immutable snapshot of current TTS playback state.
@immutable
class TtsPlaybackState {
  const TtsPlaybackState({
    this.state = TtsState.idle,
    this.activeMessageId,
    this.error,
  });

  final TtsState state;
  final String? activeMessageId;
  final String? error;

  bool get isPlaying => state == TtsState.playing;
  bool get isPaused => state == TtsState.paused;
  bool get isIdle => state == TtsState.idle;

  bool isMessagePlaying(String messageId) =>
      isPlaying && activeMessageId == messageId;

  bool isMessagePaused(String messageId) =>
      isPaused && activeMessageId == messageId;

  bool isMessageActive(String messageId) => activeMessageId == messageId;

  TtsPlaybackState copyWith({
    TtsState? state,
    String? activeMessageId,
    String? error,
  }) =>
      TtsPlaybackState(
        state: state ?? this.state,
        activeMessageId: activeMessageId ?? this.activeMessageId,
        error: error,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsPlaybackState &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          activeMessageId == other.activeMessageId &&
          error == other.error;

  @override
  int get hashCode =>
      state.hashCode ^ activeMessageId.hashCode ^ error.hashCode;
}

/// Production Text-to-Speech service utilizing native device TTS via `flutter_tts`.
/// Handles speech synthesis, single-stream playback enforcement, markdown cleaning,
/// long-form chunking, pause/resume, and UI reactive state notifications.
class TextToSpeechService {
  /// In production, uses real `FlutterTts`. An optional [tts] parameter can be
  /// injected strictly for automated unit tests.
  TextToSpeechService({FlutterTts? tts}) : _flutterTts = tts ?? FlutterTts() {
    _initTts();
  }

  final FlutterTts _flutterTts;
  final ValueNotifier<TtsPlaybackState> stateNotifier =
      ValueNotifier<TtsPlaybackState>(const TtsPlaybackState());

  TtsPlaybackState get currentState => stateNotifier.value;

  // Track playback chunks for the active message
  List<String> _currentChunks = [];
  int _currentChunkIndex = 0;
  bool _isDisposed = false;
  bool _isInitialized = false;

  /// Initialize TTS callbacks and native audio settings.
  Future<void> _initTts() async {
    if (_isInitialized) {
      return;
    }

    try {
      _flutterTts.setStartHandler(() {
        if (!_isDisposed && currentState.state != TtsState.playing) {
          stateNotifier.value = currentState.copyWith(state: TtsState.playing);
        }
      });

      _flutterTts.setCompletionHandler(_onChunkComplete);

      _flutterTts.setPauseHandler(() {
        if (!_isDisposed && currentState.state != TtsState.paused) {
          stateNotifier.value = currentState.copyWith(state: TtsState.paused);
        }
      });

      _flutterTts.setContinueHandler(() {
        if (!_isDisposed && currentState.state != TtsState.playing) {
          stateNotifier.value = currentState.copyWith(state: TtsState.playing);
        }
      });

      _flutterTts.setErrorHandler((dynamic msg) {
        debugPrint('[TextToSpeechService] TTS engine error: $msg');
        if (!_isDisposed) {
          stateNotifier.value = TtsPlaybackState(
            state: TtsState.idle,
            activeMessageId: null,
            error: msg?.toString() ?? 'Speech synthesis error',
          );
        }
      });

      // Default rate, pitch, and volume for clear educational speech
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1);
      await _flutterTts.setVolume(1);

      _isInitialized = true;
    } catch (e) {
      debugPrint('[TextToSpeechService] Initialization error: $e');
    }
  }

  /// Cleans raw markdown into human-friendly spoken text:
  /// - Strips headings, bold, italic, strikethrough, blockquotes
  /// - Replaces code blocks with "Here is a code example."
  /// - Unwraps inline code and markdown links
  /// - Strips images and HTML tags
  /// - Cleans markdown table pipes and dividers
  /// - Normalizes bullet points and excessive whitespace
  static String cleanMarkdownForSpeech(String markdown) {
    if (markdown.trim().isEmpty) {
      return '';
    }

    var cleaned = markdown;

    // 1. Strip images: ![alt](url) -> ""
    cleaned = cleaned.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '');

    // 2. Replace fenced code blocks: ```lang ... ``` -> "Here is a code example."
    cleaned = cleaned.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      '\nHere is a code example.\n',
    );

    // 3. Strip inline code: `code` -> code
    cleaned = cleaned.replaceAllMapped(
      RegExp('`([^`]+)`'),
      (match) => match.group(1) ?? '',
    );

    // 4. Strip markdown links: [text](url) -> text
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (match) => match.group(1) ?? '',
    );

    // 5. Strip markdown headers (# Header)
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*#{1,6}\s+', multiLine: true),
      '',
    );

    // 6. Strip bold and italic: **bold**, *italic*, __bold__, _italic_
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => match.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp('__([^_]+)__'),
      (match) => match.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (match) => match.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!\w)_([^_]+)_(?!\w)'),
      (match) => match.group(1) ?? '',
    );

    // 7. Strip strikethrough: ~~text~~ -> text
    cleaned = cleaned.replaceAllMapped(
      RegExp('~~([^~]+)~~'),
      (match) => match.group(1) ?? '',
    );

    // 8. Strip blockquotes: > quote -> quote
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*>\s?', multiLine: true),
      '',
    );

    // 9. Strip horizontal rules (---, ***, ___)
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*([-*_]){3,}\s*$', multiLine: true),
      '',
    );

    // 10. Strip table dividers: |---|---|
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*\|?[-:\s|]+\|?\s*$', multiLine: true),
      '',
    );

    // 11. Clean table row delimiters: replace remaining '|' with pause/comma
    cleaned = cleaned.replaceAll('|', ', ');

    // 12. Strip list bullet markers: *, -, + at start of line
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*[-*+]\s+', multiLine: true),
      '',
    );

    // 13. Strip HTML tags
    cleaned = cleaned.replaceAll(RegExp('<[^>]+>'), '');

    // 14. Normalize mathematical notation: $$...$$ -> formula
    cleaned = cleaned.replaceAll(
      RegExp(r'\$\$[\s\S]*?\$\$'),
      ' formula ',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\$([^\$]+)\$'),
      (match) => match.group(1) ?? '',
    );

    // 15. Normalize whitespace and newlines
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned.trim();
  }

  /// Splits text into natural speech chunks (by paragraphs or sentences)
  /// to avoid mobile OS TTS buffer limits (~4000 characters).
  static List<String> chunkTextForSpeech(String text, {int maxChunkSize = 2500}) {
    if (text.isEmpty) {
      return [];
    }
    if (text.length <= maxChunkSize) {
      return [text];
    }

    final chunks = <String>[];
    final paragraphs = text.split('\n\n');
    var currentChunk = '';

    for (final paragraph in paragraphs) {
      final p = paragraph.trim();
      if (p.isEmpty) {
        continue;
      }

      if ((currentChunk.length + p.length + 2) <= maxChunkSize) {
        currentChunk = currentChunk.isEmpty ? p : '$currentChunk\n\n$p';
      } else {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());
          currentChunk = '';
        }

        // If single paragraph is larger than maxChunkSize, split by sentence
        if (p.length > maxChunkSize) {
          final sentences = p.split(RegExp(r'(?<=[.?!])\s+'));
          for (final sentence in sentences) {
            final s = sentence.trim();
            if (s.isEmpty) {
              continue;
            }

            if ((currentChunk.length + s.length + 1) <= maxChunkSize) {
              currentChunk = currentChunk.isEmpty ? s : '$currentChunk $s';
            } else {
              if (currentChunk.isNotEmpty) {
                chunks.add(currentChunk.trim());
              }
              currentChunk = s;
            }
          }
        } else {
          currentChunk = p;
        }
      }
    }

    if (currentChunk.trim().isNotEmpty) {
      chunks.add(currentChunk.trim());
    }

    return chunks.isEmpty ? [text] : chunks;
  }

  /// Starts or toggles speech for [messageId] with [rawMarkdown].
  /// If another message was playing, it stops it first (ensuring single playback).
  /// If the same message was paused, it resumes.
  Future<void> speak(String messageId, String rawMarkdown) async {
    // If this message is currently paused, resume it
    if (currentState.isMessagePaused(messageId)) {
      await resume();
      return;
    }

    // If another message or this message is currently playing, stop it first
    if (currentState.isPlaying) {
      await stop();
    }

    final speechText = cleanMarkdownForSpeech(rawMarkdown);
    if (speechText.isEmpty) {
      stateNotifier.value = const TtsPlaybackState(state: TtsState.idle);
      return;
    }

    _currentChunks = chunkTextForSpeech(speechText);
    _currentChunkIndex = 0;

    stateNotifier.value = TtsPlaybackState(
      state: TtsState.playing,
      activeMessageId: messageId,
    );

    await _speakCurrentChunk();
  }

  /// Speaks the chunk at [_currentChunkIndex].
  Future<void> _speakCurrentChunk() async {
    if (_isDisposed) {
      return;
    }
    if (_currentChunkIndex >= _currentChunks.length) {
      // Completed all chunks
      stateNotifier.value = const TtsPlaybackState(state: TtsState.idle);
      return;
    }

    try {
      final chunk = _currentChunks[_currentChunkIndex];
      final result = await _flutterTts.speak(chunk);
      if (result == 0) {
        debugPrint('[TextToSpeechService] speak returned 0 (failed or queued)');
      }
    } catch (e) {
      debugPrint('[TextToSpeechService] Error in speak: $e');
      if (!_isDisposed) {
        stateNotifier.value = TtsPlaybackState(
          state: TtsState.idle,
          error: e.toString(),
        );
      }
    }
  }

  /// Called when a chunk finishes speaking.
  void _onChunkComplete() {
    if (_isDisposed) {
      return;
    }

    if (currentState.state == TtsState.playing) {
      _currentChunkIndex++;
      if (_currentChunkIndex < _currentChunks.length) {
        _speakCurrentChunk();
      } else {
        // All speech completed
        _currentChunks = [];
        _currentChunkIndex = 0;
        stateNotifier.value = const TtsPlaybackState(state: TtsState.idle);
      }
    }
  }

  /// Pauses current playback if playing.
  Future<void> pause() async {
    if (!currentState.isPlaying) {
      return;
    }

    try {
      await _flutterTts.pause();
    } catch (e) {
      debugPrint('[TextToSpeechService] Error pausing TTS: $e');
    } finally {
      if (!_isDisposed) {
        stateNotifier.value = currentState.copyWith(state: TtsState.paused);
      }
    }
  }

  /// Resumes playback if paused.
  Future<void> resume() async {
    if (!currentState.isPaused) {
      return;
    }

    try {
      stateNotifier.value = currentState.copyWith(state: TtsState.playing);
      // If native pause is supported, continue from current chunk
      if (_currentChunkIndex < _currentChunks.length) {
        await _flutterTts.speak(_currentChunks[_currentChunkIndex]);
      } else {
        stateNotifier.value = const TtsPlaybackState(state: TtsState.idle);
      }
    } catch (e) {
      debugPrint('[TextToSpeechService] Error resuming TTS: $e');
      if (!_isDisposed) {
        stateNotifier.value = TtsPlaybackState(
          state: TtsState.idle,
          error: e.toString(),
        );
      }
    }
  }

  /// Stops TTS playback and resets active state.
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('[TextToSpeechService] Error stopping TTS: $e');
    } finally {
      _currentChunks = [];
      _currentChunkIndex = 0;
      if (!_isDisposed) {
        stateNotifier.value = const TtsPlaybackState(state: TtsState.idle);
      }
    }
  }

  /// Stops playback and disposes listeners.
  void dispose() {
    _isDisposed = true;
    _flutterTts.stop();
    stateNotifier.dispose();
  }
}
