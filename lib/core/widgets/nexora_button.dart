import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Nexora primary button
class NexoraButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;
  final double height;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const NexoraButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
    this.height = NexoraSpacing.buttonHeightMD,
    this.textStyle,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(key: key);

  @override
  State<NexoraButton> createState() => _NexoraButtonState();
}

class _NexoraButtonState extends State<NexoraButton> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ElevatedButton(
        onPressed: widget.isEnabled && !widget.isLoading ? widget.onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor ?? Color(NexoraColors.primary),
          foregroundColor: widget.foregroundColor ?? Color(NexoraColors.surface),
          disabledBackgroundColor: Color(NexoraColors.gray4),
          disabledForegroundColor: Color(NexoraColors.textMuted),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
          ),
        ),
        child: widget.isLoading
            ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.foregroundColor ?? Color(NexoraColors.surface),
            ),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.leadingIcon != null) ...[
              Icon(widget.leadingIcon, size: 20),
              SizedBox(width: NexoraSpacing.sm),
            ],
            Text(
              widget.label,
              style: widget.textStyle ?? NexoraTypography.button,
            ),
            if (widget.trailingIcon != null) ...[
              SizedBox(width: NexoraSpacing.sm),
              Icon(widget.trailingIcon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nexora secondary/outline button
class NexoraOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;
  final double height;
  final Color? borderColor;
  final Color? textColor;

  const NexoraOutlineButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
    this.height = NexoraSpacing.buttonHeightMD,
    this.borderColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: borderColor ?? Color(NexoraColors.primary),
            width: 2,
          ),
          disabledForegroundColor: Color(NexoraColors.textMuted),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
          ),
        ),
        child: isLoading
            ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              textColor ?? Color(NexoraColors.primary),
            ),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 20),
              SizedBox(width: NexoraSpacing.sm),
            ],
            Text(
              label,
              style: NexoraTypography.button.copyWith(
                color: textColor ?? Color(NexoraColors.primary),
              ),
            ),
            if (trailingIcon != null) ...[
              SizedBox(width: NexoraSpacing.sm),
              Icon(trailingIcon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nexora text button
class NexoraTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final TextStyle? textStyle;
  final Color? textColor;
  final bool isEnabled;

  const NexoraTextButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.textStyle,
    this.textColor,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isEnabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: textColor ?? Color(NexoraColors.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 20),
            SizedBox(width: NexoraSpacing.sm),
          ],
          Text(
            label,
            style: textStyle ??
                NexoraTypography.button.copyWith(
                  color: textColor ?? Color(NexoraColors.primary),
                ),
          ),
          if (trailingIcon != null) ...[
            SizedBox(width: NexoraSpacing.sm),
            Icon(trailingIcon, size: 20),
          ],
        ],
      ),
    );
  }
}
