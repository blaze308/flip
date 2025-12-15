import 'package:flutter/material.dart';
import 'dart:developer' as developer;

enum ToasterType { success, error, warning, info }

class CustomToaster extends StatefulWidget {
  final String message;
  final ToasterType type;
  final Duration duration;
  final VoidCallback? onDismiss;

  const CustomToaster({
    super.key,
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 4),
    this.onDismiss,
  });

  @override
  State<CustomToaster> createState() => _CustomToasterState();
}

class _CustomToasterState extends State<CustomToaster>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _animationController.reverse();
    if (mounted && widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case ToasterType.success:
        return const Color(0xFF4ECDC4);
      case ToasterType.error:
        return const Color(0xFFE74C3C);
      case ToasterType.warning:
        return const Color(0xFFF39C12);
      case ToasterType.info:
        return const Color(0xFF3498DB);
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case ToasterType.success:
        return Icons.check_circle_outline;
      case ToasterType.error:
        return Icons.error_outline;
      case ToasterType.warning:
        return Icons.warning_amber_outlined;
      case ToasterType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(_getIcon(), color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _dismiss,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToasterService {
  static OverlayEntry? _currentToaster;

  /// Show a success toaster with friendly message
  static void showSuccess(
    BuildContext context,
    String userMessage, {
    String? devMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (devMessage != null) {
      developer.log('SUCCESS: $devMessage', name: 'ToasterService');
    }
    _showToaster(context, userMessage, ToasterType.success, duration);
  }

  /// Show an error toaster with friendly message
  static void showError(
    BuildContext context,
    String userMessage, {
    String? devMessage,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (devMessage != null) {
      developer.log('ERROR: $devMessage', name: 'ToasterService');
    }
    _showToaster(context, userMessage, ToasterType.error, duration);
  }

  /// Show a warning toaster with friendly message
  static void showWarning(
    BuildContext context,
    String userMessage, {
    String? devMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (devMessage != null) {
      developer.log('WARNING: $devMessage', name: 'ToasterService');
    }
    _showToaster(context, userMessage, ToasterType.warning, duration);
  }

  /// Show an info toaster with friendly message
  static void showInfo(
    BuildContext context,
    String userMessage, {
    String? devMessage,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (devMessage != null) {
      developer.log('INFO: $devMessage', name: 'ToasterService');
    }
    _showToaster(context, userMessage, ToasterType.info, duration);
  }

  static void _showToaster(
    BuildContext context,
    String message,
    ToasterType type,
    Duration duration,
  ) {
    // Remove existing toaster if any
    _currentToaster?.remove();
    _currentToaster = null;

    // Check if context is still mounted/valid before accessing overlay
    if (!context.mounted) {
      developer.log(
        'Context not mounted, cannot show toaster',
        name: 'ToasterService',
      );
      return;
    }

    try {
      final overlay = Overlay.of(context);
      _currentToaster = OverlayEntry(
        builder:
            (context) => Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: CustomToaster(
                  message: message,
                  type: type,
                  duration: duration,
                  onDismiss: () {
                    _currentToaster?.remove();
                    _currentToaster = null;
                  },
                ),
              ),
            ),
      );

      overlay.insert(_currentToaster!);
    } catch (e) {
      developer.log('Error showing toaster: $e', name: 'ToasterService');
      _currentToaster = null;
    }
  }

  /// Hide current toaster if any
  static void hide() {
    _currentToaster?.remove();
    _currentToaster = null;
  }
}

/// Extension to make it easier to show toasters from any widget
extension ToasterExtension on BuildContext {
  void showSuccessToaster(
    String userMessage, {
    String? devMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    ToasterService.showSuccess(
      this,
      userMessage,
      devMessage: devMessage,
      duration: duration,
    );
  }

  void showErrorToaster(
    String userMessage, {
    String? devMessage,
    Duration duration = const Duration(seconds: 5),
  }) {
    ToasterService.showError(
      this,
      userMessage,
      devMessage: devMessage,
      duration: duration,
    );
  }

  void showWarningToaster(
    String userMessage, {
    String? devMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    ToasterService.showWarning(
      this,
      userMessage,
      devMessage: devMessage,
      duration: duration,
    );
  }

  void showInfoToaster(
    String userMessage, {
    String? devMessage,
    Duration duration = const Duration(seconds: 3),
  }) {
    ToasterService.showInfo(
      this,
      userMessage,
      devMessage: devMessage,
      duration: duration,
    );
  }
}
