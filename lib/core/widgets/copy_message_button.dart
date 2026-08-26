import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

/// Production-ready reusable copy button for assistant messages.
/// Manages its own per-message "Copied" transient feedback state safely.
class CopyMessageButton extends StatefulWidget {
  final String text;
  final String tooltip;
  final Color? iconColor;
  final Color? activeColor;
  final double iconSize;

  const CopyMessageButton({
    Key? key,
    required this.text,
    this.tooltip = 'Copy response',
    this.iconColor,
    this.activeColor,
    this.iconSize = 16.0,
  }) : super(key: key);

  @override
  State<CopyMessageButton> createState() => _CopyMessageButtonState();
}

class _CopyMessageButtonState extends State<CopyMessageButton> {
  bool _isCopied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    if (widget.text.isEmpty) return;

    try {
      await Clipboard.setData(ClipboardData(text: widget.text));

      if (!mounted) return;

      _resetTimer?.cancel();
      setState(() {
        _isCopied = true;
      });

      _resetTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });
    } catch (e) {
      debugPrint('[CopyMessageButton] Error copying to clipboard: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not copy to clipboard'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.iconColor ?? const Color(NexoraColors.textMuted);
    final activeColor = widget.activeColor ?? const Color(0xFF2E7D32);

    return Tooltip(
      message: _isCopied ? 'Copied' : widget.tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleCopy,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: _isCopied
                  ? Row(
                      key: const ValueKey('copied_state'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: widget.iconSize,
                          color: activeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Copied',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: activeColor,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('idle_state'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_outlined,
                          size: widget.iconSize,
                          color: defaultColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: defaultColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
