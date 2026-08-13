import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Nexora text field / input widget
class NexoraTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final String? initialValue;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final Color? fillColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final EdgeInsets? contentPadding;

  const NexoraTextField({
    Key? key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.validator,
    this.initialValue,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.fillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.contentPadding,
  }) : super(key: key);

  @override
  State<NexoraTextField> createState() => _NexoraTextFieldState();
}

class _NexoraTextFieldState extends State<NexoraTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: NexoraTypography.labelMedium,
          ),
          SizedBox(height: NexoraSpacing.sm),
        ],
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: _obscureText,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          maxLines: _obscureText ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          validator: widget.validator,
          textCapitalization: widget.textCapitalization,
          focusNode: widget.focusNode,
          style: NexoraTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: NexoraTypography.bodyMedium.copyWith(
              color: Color(NexoraColors.textMuted),
            ),
            errorText: widget.errorText,
            filled: true,
            fillColor: widget.fillColor ?? Color(NexoraColors.inputBackground),
            contentPadding: widget.contentPadding ??
                EdgeInsets.symmetric(
                  horizontal: NexoraSpacing.lg,
                  vertical: NexoraSpacing.md,
                ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
              borderSide: BorderSide(
                color: widget.borderColor ?? Color(NexoraColors.border),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
              borderSide: BorderSide(
                color: widget.borderColor ?? Color(NexoraColors.border),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
              borderSide: BorderSide(
                color: widget.focusedBorderColor ?? Color(NexoraColors.primary),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
              borderSide: BorderSide(
                color: Color(NexoraColors.error),
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
              borderSide: BorderSide(
                color: Color(NexoraColors.error),
                width: 2,
              ),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
              widget.prefixIcon,
              color: Color(NexoraColors.textMuted),
            )
                : null,
            suffixIcon: widget.suffixIcon != null
                ? GestureDetector(
              onTap: widget.onSuffixIconTap ??
                  (widget.obscureText
                      ? () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  }
                      : null),
              child: Icon(
                widget.suffixIcon,
                color: Color(NexoraColors.textMuted),
              ),
            )
                : null,
          ),
        ),
      ],
    );
  }
}
