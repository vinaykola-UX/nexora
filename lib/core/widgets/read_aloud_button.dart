import 'package:flutter/material.dart';
import '../../services/text_to_speech_service.dart';
import '../theme/colors.dart';

/// Production-ready reusable Read Aloud / TTS button for assistant messages.
/// Listens reactively to [TextToSpeechService] state to render idle, playing,
/// and paused states with smooth micro-animations.
class ReadAloudButton extends StatelessWidget {
  const ReadAloudButton({
    required this.messageId,
    required this.text,
    required this.ttsService,
    super.key,
    this.enabled = true,
    this.iconColor,
    this.activeColor,
    this.iconSize = 16.0,
  });

  final String messageId;
  final String text;
  final TextToSpeechService ttsService;
  final bool enabled;
  final Color? iconColor;
  final Color? activeColor;
  final double iconSize;

  Future<void> _handleTap() async {
    if (!enabled || text.trim().isEmpty) {
      return;
    }

    final currentState = ttsService.currentState;

    if (currentState.isMessagePlaying(messageId)) {
      await ttsService.pause();
    } else if (currentState.isMessagePaused(messageId)) {
      await ttsService.resume();
    } else {
      await ttsService.speak(messageId, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultColor =
        iconColor ?? const Color(NexoraColors.textMuted);
    final activeThemeColor =
        activeColor ?? const Color(NexoraColors.primaryDark);

    return ValueListenableBuilder<TtsPlaybackState>(
      valueListenable: ttsService.stateNotifier,
      builder: (context, playbackState, _) {
        final isPlaying = playbackState.isMessagePlaying(messageId);
        final isPaused = playbackState.isMessagePaused(messageId);
        final isActive = isPlaying || isPaused;

        final String tooltipMessage;
        final String semanticsLabel;
        final String labelText;
        final IconData iconData;
        final Color currentColor;

        if (!enabled) {
          tooltipMessage = 'Response streaming...';
          semanticsLabel = 'Read aloud unavailable while generating response';
          labelText = 'Read';
          iconData = Icons.volume_up_rounded;
          currentColor = defaultColor.withAlpha(102);
        } else if (isPlaying) {
          tooltipMessage = 'Pause read aloud';
          semanticsLabel = 'Pause read aloud';
          labelText = 'Pause';
          iconData = Icons.pause_rounded;
          currentColor = activeThemeColor;
        } else if (isPaused) {
          tooltipMessage = 'Resume read aloud';
          semanticsLabel = 'Resume read aloud';
          labelText = 'Resume';
          iconData = Icons.play_arrow_rounded;
          currentColor = activeThemeColor;
        } else {
          tooltipMessage = 'Read aloud';
          semanticsLabel = 'Read response aloud';
          labelText = 'Read';
          iconData = Icons.volume_up_rounded;
          currentColor = defaultColor;
        }

        return Semantics(
          label: semanticsLabel,
          button: true,
          enabled: enabled,
          child: Tooltip(
            message: tooltipMessage,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? _handleTap : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Row(
                      key: ValueKey<String>(
                        '${messageId}_${isPlaying ? "playing" : (isPaused ? "paused" : "idle")}',
                      ),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          iconData,
                          size: iconSize,
                          color: currentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          labelText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: currentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
