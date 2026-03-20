import 'package:flutter/material.dart';

/// Stub implementation for platforms where in-app update is not supported (web, iOS).
/// The real implementation is in [in_app_update_service_impl.dart] (Android).
class InAppUpdateService {
  InAppUpdateService._();
  static final InAppUpdateService _instance = InAppUpdateService._();
  static InAppUpdateService get instance => _instance;

  bool get isSupported => false;
  bool get isFlexibleUpdateReady => false;

  Future<void> checkForUpdate(BuildContext context) async {}

  Future<void> completeFlexibleUpdate(BuildContext context) async {}
}
