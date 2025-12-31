import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/services/accessibility_service.dart';
import 'package:n3rd_game/utils/provider_helper.dart';

/// Accessibility helper utilities for consistent accessibility implementation
///
/// Provides helper methods for:
/// - Semantics widget creation
/// - Focus management
/// - Text scaling support
/// - Screen reader announcements
class AccessibilityHelper {
  /// Create a Semantics widget for a button
  static Widget buttonSemantics({
    required Widget child,
    required String label,
    String? hint,
    bool enabled = true,
    bool? selected,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: enabled,
      selected: selected,
      onTap: onTap,
      child: child,
    );
  }

  /// Create a Semantics widget for an icon button
  static Widget iconButtonSemantics({
    required Widget child,
    required String label,
    String? hint,
    bool enabled = true,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: enabled,
      child: child,
    );
  }

  /// Create a Semantics widget for a text field
  static Widget textFieldSemantics({
    required Widget child,
    String? label,
    String? hint,
    String? value,
    bool enabled = true,
    bool readOnly = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      textField: true,
      enabled: enabled,
      readOnly: readOnly,
      child: child,
    );
  }

  /// Create a Semantics widget for an image
  static Widget imageSemantics({
    required Widget child,
    required String label,
    String? hint,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      image: true,
      child: child,
    );
  }

  /// Create a Semantics widget for a card/tile
  static Widget cardSemantics({
    required Widget child,
    String? label,
    String? hint,
    bool tappable = false,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: tappable,
      onTap: onTap,
      child: child,
    );
  }

  /// Get responsive font size based on text scale factor
  /// Applies both system text scaling and app-level fontSizeMultiplier setting
  static double getScaledFontSize(
    BuildContext context,
    double baseFontSize,
  ) {
    // Get system text scaler
    final textScaler = MediaQuery.textScalerOf(context);
    final systemScale = textScaler.scale(1.0);
    
    // Get app-level fontSizeMultiplier from AccessibilityService
    // CRITICAL: Use safeGet to prevent ProviderNotFoundException
    double appMultiplier = 1.0;
    final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(
      context,
      listen: false,
    );
    if (accessibilityService != null) {
      appMultiplier = accessibilityService.settings.fontSizeMultiplier;
    }
    
    // Apply both multipliers
    return baseFontSize * systemScale * appMultiplier;
  }

  /// Get responsive text style with text scaling support
  /// Applies both system text scaling and app-level fontSizeMultiplier setting
  static TextStyle getScaledTextStyle(
    BuildContext context,
    TextStyle baseStyle,
  ) {
    // Get system text scaler
    final textScaler = MediaQuery.textScalerOf(context);
    final systemScale = textScaler.scale(1.0);
    
    // Get app-level fontSizeMultiplier from AccessibilityService
    // CRITICAL: Use safeGet to prevent ProviderNotFoundException
    double appMultiplier = 1.0;
    final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(
      context,
      listen: false,
    );
    if (accessibilityService != null) {
      appMultiplier = accessibilityService.settings.fontSizeMultiplier;
    }
    
    // Apply both multipliers
    return baseStyle.copyWith(
      fontSize: baseStyle.fontSize != null
          ? baseStyle.fontSize! * systemScale * appMultiplier
          : null,
    );
  }

  /// Create a focusable widget with visible focus indicator
  static Widget withFocusIndicator({
    required Widget child,
    required FocusNode focusNode,
    Color? focusColor,
    double focusWidth = 2.0,
  }) {
    return Focus(
      focusNode: focusNode,
      child: Focus(
        child: Builder(
          builder: (context) {
            final colors = AppColors.of(context);
            final isFocused = focusNode.hasFocus;
            return Container(
              decoration: isFocused
                  ? BoxDecoration(
                      border: Border.all(
                        color: focusColor ?? colors.focus,
                        width: focusWidth,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: child,
            );
          },
        ),
      ),
    );
  }

  /// Request focus for a FocusNode
  static void requestFocus(
    BuildContext context,
    FocusNode focusNode,
  ) {
    if (!focusNode.hasFocus) {
      FocusScope.of(context).requestFocus(focusNode);
    }
  }

  /// Unfocus all focus nodes
  static void unfocusAll(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Announce to screen readers
  /// Note: This requires a Semantics widget in the widget tree
  static void announce(
    BuildContext context,
    String message,
  ) {
    // Use Semantics to announce - requires a Semantics widget in tree
    // For programmatic announcements, consider using a SnackBar or Dialog
    // with proper Semantics configuration
    if (isScreenReaderEnabled(context)) {
      // Show a temporary message that screen readers will pick up
      // CRITICAL: Use maybeOf to prevent null check crashes
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            child: Text(message),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Check if screen reader is enabled
  static bool isScreenReaderEnabled(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Get minimum touch target size (48x48 for accessibility)
  static Size getMinimumTouchTarget() {
    return const Size(48, 48);
  }

  /// Ensure widget meets minimum touch target size
  /// Checks AccessibilityService.settings.largerTouchTargets setting
  static Widget ensureMinimumTouchTarget(
    BuildContext context,
    Widget child, {
    double? minSize,
  }) {
    // Check if largerTouchTargets setting is enabled
    // CRITICAL: Use safeGet to prevent ProviderNotFoundException
    bool shouldEnforce = false;
    final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(
      context,
      listen: false,
    );
    if (accessibilityService != null) {
      shouldEnforce = accessibilityService.settings.largerTouchTargets;
    }
    
    // Always enforce minimum 48px when setting is enabled, otherwise use provided minSize or default
    final effectiveMinSize = shouldEnforce ? 48.0 : (minSize ?? 44.0);
    
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: effectiveMinSize,
        minHeight: effectiveMinSize,
      ),
      child: child,
    );
  }

  /// Check if larger touch targets should be enforced
  static bool shouldEnforceLargerTouchTargets(BuildContext context) {
    // CRITICAL: Use safeGet to prevent ProviderNotFoundException
    final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(
      context,
      listen: false,
    );
    if (accessibilityService != null) {
      return accessibilityService.settings.largerTouchTargets;
    }
    return false;
  }

  /// Create accessible icon with label
  static Widget accessibleIcon({
    required IconData icon,
    required String label,
    double? size,
    Color? color,
  }) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Icon(
        icon,
        size: size,
        color: color,
      ),
    );
  }

  /// Create accessible text with proper semantics
  static Widget accessibleText({
    required String text,
    TextStyle? style,
    String? semanticsLabel,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: excludeSemantics,
      child: Text(
        text,
        style: style,
      ),
    );
  }

  /// Create accessible loading indicator with semantic label
  static Widget loadingSemantics({
    required Widget child,
    required String label,
    String? hint,
  }) {
    return Semantics(
      label: label,
      hint: hint ?? 'Loading in progress',
      child: child,
    );
  }
}
