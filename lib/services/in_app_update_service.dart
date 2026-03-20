// Conditional export: use Android implementation when dart:io is available (mobile/desktop),
// stub otherwise (web). See https://pub.dev/packages/in_app_update
export 'in_app_update_service_stub.dart'
    if (dart.library.io) 'in_app_update_service_impl.dart';
