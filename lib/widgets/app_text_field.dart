import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';

/// Standardized text field component with states, labels, and icons
///
/// **States:**
/// - normal: Default state
/// - focused: When field has focus
/// - error: When validation fails
/// - disabled: When field is disabled
///
/// **Usage:**
/// ```dart
/// AppTextField(
///   label: 'Email',
///   hint: 'Enter your email',
///   onChanged: (value) => _email = value,
/// )
/// ```
class AppTextField extends StatefulWidget {

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.leadingIcon,
    this.trailingIcon,
    this.onTrailingIconTap,
    this.inputFormatters,
    this.focusNode,
    this.semanticsLabel,
    this.semanticsHint,
  });
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? maxLength;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingIconTap;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final String? semanticsLabel;
  final String? semanticsHint;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasFocusNode = false;

  @override
  void initState() {
    super.initState();
    _hasFocusNode = widget.focusNode != null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (!_hasFocusNode) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final isDisabled = !widget.enabled;

    // Determine field state
    final fieldState = isDisabled
        ? _FieldState.disabled
        : hasError
            ? _FieldState.error
            : _isFocused
                ? _FieldState.focused
                : _FieldState.normal;

    final fieldStyle = _getFieldStyle(context, colors, fieldState);

    final Widget textField = TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      obscureText: widget.obscureText,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      focusNode: _focusNode,
      style: AppTypography.bodyMedium.copyWith(
        color: fieldStyle.textColor,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        errorText: widget.errorText,
        prefixIcon: widget.leadingIcon != null
            ? Icon(
                widget.leadingIcon,
                color: fieldStyle.iconColor,
              )
            : null,
        suffixIcon: widget.trailingIcon != null
            ? IconButton(
                icon: Icon(
                  widget.trailingIcon,
                  color: fieldStyle.iconColor,
                ),
                onPressed: widget.onTrailingIconTap,
              )
            : null,
        filled: true,
        fillColor: fieldStyle.backgroundColor,
        enabled: widget.enabled,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: fieldStyle.borderColor,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: fieldStyle.borderColor,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: fieldStyle.focusColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: colors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: colors.error,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: fieldStyle.borderColor,
            width: 1,
          ),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: fieldStyle.labelColor,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: fieldStyle.hintColor,
        ),
        helperStyle: AppTypography.bodySmall.copyWith(
          color: fieldStyle.helperColor,
        ),
        errorStyle: AppTypography.bodySmall.copyWith(
          color: colors.error,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );

    // Wrap with Semantics for accessibility
    return Semantics(
      label: widget.semanticsLabel ?? widget.label,
      hint: widget.semanticsHint ?? widget.hint,
      textField: true,
      enabled: widget.enabled,
      child: textField,
    );
  }

  _FieldStyle _getFieldStyle(
    BuildContext context,
    AppColorScheme colors,
    _FieldState state,
  ) {
    switch (state) {
      case _FieldState.normal:
        return _FieldStyle(
          backgroundColor: colors.surface,
          textColor: colors.primaryText,
          labelColor: colors.secondaryText,
          hintColor: colors.tertiaryText,
          helperColor: colors.secondaryText,
          iconColor: colors.secondaryText,
          borderColor: colors.borderLight,
          focusColor: colors.focus,
        );
      case _FieldState.focused:
        return _FieldStyle(
          backgroundColor: colors.surface,
          textColor: colors.primaryText,
          labelColor: colors.focus,
          hintColor: colors.tertiaryText,
          helperColor: colors.secondaryText,
          iconColor: colors.focus,
          borderColor: colors.focus,
          focusColor: colors.focus,
        );
      case _FieldState.error:
        return _FieldStyle(
          backgroundColor: colors.surface,
          textColor: colors.primaryText,
          labelColor: colors.error,
          hintColor: colors.tertiaryText,
          helperColor: colors.error,
          iconColor: colors.error,
          borderColor: colors.error,
          focusColor: colors.error,
        );
      case _FieldState.disabled:
        return _FieldStyle(
          backgroundColor: colors.surfaceVariant,
          textColor: colors.disabledText,
          labelColor: colors.disabledText,
          hintColor: colors.disabledText,
          helperColor: colors.disabledText,
          iconColor: colors.disabledText,
          borderColor: colors.borderLight,
          focusColor: colors.focus,
        );
    }
  }
}

/// Field state enum
enum _FieldState {
  normal,
  focused,
  error,
  disabled,
}

/// Internal field style
class _FieldStyle {

  _FieldStyle({
    required this.backgroundColor,
    required this.textColor,
    required this.labelColor,
    required this.hintColor,
    required this.helperColor,
    required this.iconColor,
    required this.borderColor,
    required this.focusColor,
  });
  final Color backgroundColor;
  final Color textColor;
  final Color labelColor;
  final Color hintColor;
  final Color helperColor;
  final Color iconColor;
  final Color borderColor;
  final Color focusColor;
}
















