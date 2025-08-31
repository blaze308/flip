import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service to handle optimistic UI updates with rollback capability
///
/// This service implements the strategy:
/// - For quick actions (like, bookmark): Update UI immediately, send API request in background, revert if fails
/// - For slow actions (OTP, auth): Show loading state, disable button, notify user of progress
class OptimisticUIService {
  static final Map<String, Timer> _pendingOperations = {};
  static final Map<String, VoidCallback> _rollbackCallbacks = {};

  /// Performs an optimistic update for quick actions
  ///
  /// [operationId] - Unique identifier for this operation
  /// [optimisticUpdate] - Function to update UI immediately
  /// [apiCall] - Function that performs the actual API call
  /// [rollback] - Function to revert UI changes if API fails
  /// [onSuccess] - Optional callback when API succeeds
  /// [onError] - Optional callback when API fails
  static Future<void> performOptimisticUpdate({
    required String operationId,
    required VoidCallback optimisticUpdate,
    required Future<bool> Function() apiCall,
    required VoidCallback rollback,
    VoidCallback? onSuccess,
    void Function(String error)? onError,
  }) async {
    // Cancel any pending operation with the same ID
    cancelOperation(operationId);

    // Perform optimistic update immediately
    optimisticUpdate();

    // Store rollback callback
    _rollbackCallbacks[operationId] = rollback;

    // Set a timeout for the operation
    _pendingOperations[operationId] = Timer(const Duration(seconds: 10), () {
      // Timeout - rollback the change
      if (_rollbackCallbacks.containsKey(operationId)) {
        _rollbackCallbacks[operationId]!();
        _rollbackCallbacks.remove(operationId);
        onError?.call('Operation timed out');
      }
      _pendingOperations.remove(operationId);
    });

    try {
      // Perform API call in background
      final success = await apiCall();

      // Cancel timeout timer
      _pendingOperations[operationId]?.cancel();
      _pendingOperations.remove(operationId);
      _rollbackCallbacks.remove(operationId);

      if (success) {
        onSuccess?.call();
      } else {
        // API failed - rollback
        rollback();
        onError?.call('Operation failed');
      }
    } catch (e) {
      // API call threw exception - rollback
      _pendingOperations[operationId]?.cancel();
      _pendingOperations.remove(operationId);
      _rollbackCallbacks.remove(operationId);

      rollback();
      onError?.call(e.toString());
    }
  }

  /// Cancels a pending operation and performs rollback if needed
  static void cancelOperation(String operationId) {
    _pendingOperations[operationId]?.cancel();
    _pendingOperations.remove(operationId);

    if (_rollbackCallbacks.containsKey(operationId)) {
      _rollbackCallbacks[operationId]!();
      _rollbackCallbacks.remove(operationId);
    }
  }

  /// Checks if an operation is currently pending
  static bool isOperationPending(String operationId) {
    return _pendingOperations.containsKey(operationId);
  }

  /// Clears all pending operations (useful for cleanup)
  static void clearAllOperations() {
    for (final timer in _pendingOperations.values) {
      timer.cancel();
    }
    _pendingOperations.clear();
    _rollbackCallbacks.clear();
  }
}

/// Mixin for widgets that need optimistic UI updates
mixin OptimisticUIMixin<T extends StatefulWidget> on State<T> {
  final Set<String> _disabledButtons = {};

  /// Disables a button to prevent double-tap
  void disableButton(String buttonId) {
    setState(() {
      _disabledButtons.add(buttonId);
    });
  }

  /// Enables a button after operation completes
  void enableButton(String buttonId) {
    setState(() {
      _disabledButtons.remove(buttonId);
    });
  }

  /// Checks if a button is currently disabled
  bool isButtonDisabled(String buttonId) {
    return _disabledButtons.contains(buttonId);
  }

  /// Performs an optimistic update with button state management
  Future<void> performOptimisticAction({
    required String buttonId,
    required VoidCallback optimisticUpdate,
    required Future<bool> Function() apiCall,
    required VoidCallback rollback,
    VoidCallback? onSuccess,
    void Function(String error)? onError,
  }) async {
    if (isButtonDisabled(buttonId)) return;

    disableButton(buttonId);

    await OptimisticUIService.performOptimisticUpdate(
      operationId: buttonId,
      optimisticUpdate: optimisticUpdate,
      apiCall: apiCall,
      rollback: rollback,
      onSuccess: () {
        enableButton(buttonId);
        onSuccess?.call();
      },
      onError: (error) {
        enableButton(buttonId);
        onError?.call(error);
      },
    );
  }

  @override
  void dispose() {
    // Clean up any pending operations for this widget
    for (final buttonId in _disabledButtons) {
      OptimisticUIService.cancelOperation(buttonId);
    }
    super.dispose();
  }
}

/// Button state for loading operations
enum LoadingButtonState { idle, loading, success, error }

/// Data class for button state management
class ButtonState {
  final LoadingButtonState state;
  final String? message;
  final bool isDisabled;

  const ButtonState({
    this.state = LoadingButtonState.idle,
    this.message,
    this.isDisabled = false,
  });

  ButtonState copyWith({
    LoadingButtonState? state,
    String? message,
    bool? isDisabled,
  }) {
    return ButtonState(
      state: state ?? this.state,
      message: message ?? this.message,
      isDisabled: isDisabled ?? this.isDisabled,
    );
  }

  bool get isLoading => state == LoadingButtonState.loading;
  bool get isSuccess => state == LoadingButtonState.success;
  bool get isError => state == LoadingButtonState.error;
  bool get isIdle => state == LoadingButtonState.idle;
}
