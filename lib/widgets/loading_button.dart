import 'package:flutter/material.dart';
import '../services/optimistic_ui_service.dart';

/// A button widget that handles loading states and prevents double-tap
class LoadingButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonState buttonState;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final TextStyle? textStyle;
  final String? loadingText;
  final Widget? loadingIcon;

  const LoadingButton({
    super.key,
    required this.text,
    this.onPressed,
    this.buttonState = const ButtonState(),
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
    this.width,
    this.height,
    this.textStyle,
    this.loadingText,
    this.loadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled =
        buttonState.isDisabled || buttonState.isLoading || onPressed == null;
    final effectiveBackgroundColor =
        backgroundColor ?? Theme.of(context).primaryColor;
    final effectiveForegroundColor = foregroundColor ?? Colors.white;

    return SizedBox(
      width: width,
      height: height ?? 48,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDisabled
                  ? effectiveBackgroundColor.withOpacity(0.6)
                  : effectiveBackgroundColor,
          foregroundColor: effectiveForegroundColor,
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
          elevation: isDisabled ? 0 : 2,
        ),
        child: _buildButtonContent(),
      ),
    );
  }

  Widget _buildButtonContent() {
    if (buttonState.isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          loadingIcon ??
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    foregroundColor ?? Colors.white,
                  ),
                ),
              ),
          if (loadingText != null) ...[
            const SizedBox(width: 8),
            Text(loadingText!, style: textStyle),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Text(text, style: textStyle),
      ],
    );
  }
}

/// A specialized button for optimistic UI actions (like, bookmark, etc.)
class OptimisticButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;
  final EdgeInsetsGeometry? padding;
  final double? size;
  final bool isDisabled;

  const OptimisticButton({
    super.key,
    required this.child,
    this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
    this.padding,
    this.size,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? Theme.of(context).primaryColor;
    final effectiveInactiveColor = inactiveColor ?? Colors.grey;
    final currentColor =
        isActive ? effectiveActiveColor : effectiveInactiveColor;

    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: Container(
        padding: padding ?? const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isDisabled ? currentColor.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AnimatedScale(
          scale: isDisabled ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: IconTheme(
            data: IconThemeData(
              color: isDisabled ? currentColor.withOpacity(0.5) : currentColor,
              size: size ?? 24,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A button specifically for OTP and authentication flows
class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonState buttonState;
  final bool isPrimary;
  final String? successMessage;
  final String? errorMessage;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.buttonState = const ButtonState(),
    this.isPrimary = true,
    this.successMessage,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoadingButton(
          text: text,
          onPressed: onPressed,
          buttonState: buttonState,
          backgroundColor:
              isPrimary ? const Color(0xFF4ECDC4) : Colors.grey[600],
          foregroundColor: Colors.white,
          height: 56,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          loadingText: _getLoadingText(),
        ),
        if (buttonState.message != null) ...[
          const SizedBox(height: 8),
          Text(
            buttonState.message!,
            style: TextStyle(
              color: buttonState.isError ? Colors.red : Colors.green,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  String? _getLoadingText() {
    if (!buttonState.isLoading) return null;

    if (text.toLowerCase().contains('send')) {
      return 'Sending...';
    } else if (text.toLowerCase().contains('verify')) {
      return 'Verifying...';
    } else if (text.toLowerCase().contains('sign')) {
      return 'Signing in...';
    }

    return 'Loading...';
  }
}

/// Extension to easily create button states
extension ButtonStateExtension on ButtonState {
  static ButtonState loading({String? message}) => ButtonState(
    state: LoadingButtonState.loading,
    message: message,
    isDisabled: true,
  );

  static ButtonState success({String? message}) => ButtonState(
    state: LoadingButtonState.success,
    message: message,
    isDisabled: false,
  );

  static ButtonState error({String? message}) => ButtonState(
    state: LoadingButtonState.error,
    message: message,
    isDisabled: false,
  );

  static ButtonState idle({bool isDisabled = false}) =>
      ButtonState(state: LoadingButtonState.idle, isDisabled: isDisabled);
}
