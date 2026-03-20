import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

/// Notification Settings Provider
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, AsyncValue<Map<String, bool>>>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettingsNotifier extends StateNotifier<AsyncValue<Map<String, bool>>> {
  NotificationSettingsNotifier() : super(const AsyncValue.data({
    'email': true,
    'push': true,
    'sms': false,
  }));

  Future<Map<String, dynamic>> updateNotifications({
    bool? email,
    bool? push,
    bool? sms,
  }) async {
    try {
      state = const AsyncValue.loading();

      final result = await SettingsService.updateNotifications(
        email: email,
        push: push,
        sms: sms,
      );

      if (result['success'] == true && result['notifications'] != null) {
        final notifications = result['notifications'] as Map<String, dynamic>;
        state = AsyncValue.data({
          'email': notifications['email'] ?? true,
          'push': notifications['push'] ?? true,
          'sms': notifications['sms'] ?? false,
        });
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to update notifications',
          StackTrace.current,
        );
      }

      return result;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  void updateLocal(Map<String, bool> settings) {
    state = AsyncValue.data(settings);
  }
}

/// Privacy Settings Provider
final privacySettingsProvider =
    StateNotifierProvider<PrivacySettingsNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  return PrivacySettingsNotifier();
});

class PrivacySettingsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  PrivacySettingsNotifier() : super(const AsyncValue.data({
    'profileVisible': true,
    'showEmail': false,
    'showPhone': false,
    'messageWhoCan': 'everyone',
    'callWhoCan': 'everyone',
    'invisibleMode': false,
  }));

  Future<Map<String, dynamic>> updatePrivacy({
    bool? profileVisible,
    bool? showEmail,
    bool? showPhone,
    String? messageWhoCan,
    String? callWhoCan,
    bool? invisibleMode,
  }) async {
    try {
      state = const AsyncValue.loading();

      final result = await SettingsService.updatePrivacy(
        profileVisible: profileVisible,
        showEmail: showEmail,
        showPhone: showPhone,
      );

      if (result['success'] == true) {
        final currentSettings = state.value ?? {};
        state = AsyncValue.data({
          'profileVisible': profileVisible ?? currentSettings['profileVisible'] ?? true,
          'showEmail': showEmail ?? currentSettings['showEmail'] ?? false,
          'showPhone': showPhone ?? currentSettings['showPhone'] ?? false,
          'messageWhoCan': messageWhoCan ?? currentSettings['messageWhoCan'] ?? 'everyone',
          'callWhoCan': callWhoCan ?? currentSettings['callWhoCan'] ?? 'everyone',
          'invisibleMode': invisibleMode ?? currentSettings['invisibleMode'] ?? false,
        });
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to update privacy settings',
          StackTrace.current,
        );
      }

      return result;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  void updateLocal(Map<String, dynamic> settings) {
    state = AsyncValue.data(settings);
  }

  Future<void> loadFromBackend() async {
    try {
      state = const AsyncValue.loading();
      final prefs = await SettingsService.getPreferences();
      if (prefs != null) {
        final privacy = prefs['privacy'] as Map<String, dynamic>? ?? {};
        state = AsyncValue.data({
          'profileVisible': privacy['profileVisible'] ?? true,
          'showEmail': privacy['showEmail'] ?? false,
          'showPhone': privacy['showPhone'] ?? false,
          'messageWhoCan': privacy['messageWhoCan'] ?? 'everyone',
          'callWhoCan': privacy['callWhoCan'] ?? 'everyone',
          'invisibleMode': privacy['invisibleMode'] ?? false,
        });
      } else {
        state = const AsyncValue.data({
          'profileVisible': true,
          'showEmail': false,
          'showPhone': false,
          'messageWhoCan': 'everyone',
          'callWhoCan': 'everyone',
          'invisibleMode': false,
        });
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Currency Settings Provider
final currencySettingsProvider =
    StateNotifierProvider<CurrencySettingsNotifier, AsyncValue<String>>((ref) {
  return CurrencySettingsNotifier();
});

class CurrencySettingsNotifier extends StateNotifier<AsyncValue<String>> {
  CurrencySettingsNotifier() : super(const AsyncValue.data('USD'));

  Future<Map<String, dynamic>> updateCurrency(String currency) async {
    try {
      state = const AsyncValue.loading();
      final result = await SettingsService.updateCurrency(currency);
      if (result['success'] == true) {
        state = AsyncValue.data(currency);
      } else {
        state = AsyncValue.error(result['message'] ?? 'Failed', StackTrace.current);
      }
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return {'success': false, 'message': e.toString()};
    }
  }

  void setLocal(String currency) {
    state = AsyncValue.data(currency);
  }
}

/// Language Settings Provider
final languageSettingsProvider =
    StateNotifierProvider<LanguageSettingsNotifier, AsyncValue<String>>((ref) {
  return LanguageSettingsNotifier();
});

class LanguageSettingsNotifier extends StateNotifier<AsyncValue<String>> {
  LanguageSettingsNotifier() : super(const AsyncValue.data('en'));

  Future<Map<String, dynamic>> updateLanguage(String language) async {
    try {
      state = const AsyncValue.loading();

      final result = await SettingsService.updateLanguage(language);

      if (result['success'] == true) {
        state = AsyncValue.data(language);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to update language',
          StackTrace.current,
        );
      }

      return result;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  void updateLocal(String language) {
    state = AsyncValue.data(language);
  }
}

/// Sessions Provider
final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return SessionsNotifier();
});

class SessionsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  SessionsNotifier() : super(const AsyncValue.loading()) {
    _loadSessions();
  }

  List<Map<String, dynamic>> _sessions = [];

  Future<void> _loadSessions() async {
    try {
      state = const AsyncValue.loading();

      final sessions = await SettingsService.getSessions();

      _sessions = sessions;
      state = AsyncValue.data(_sessions);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadSessions();
  }

  Future<Map<String, dynamic>> deleteSession(String sessionId) async {
    final result = await SettingsService.deleteSession(sessionId);

    if (result['success'] == true) {
      _sessions.removeWhere((s) => s['_id'] == sessionId || s['id'] == sessionId);
      state = AsyncValue.data([..._sessions]);
    }

    return result;
  }
}

/// Delete Account Provider
final deleteAccountProvider =
    StateNotifierProvider<DeleteAccountNotifier, AsyncValue<bool>>((ref) {
  return DeleteAccountNotifier();
});

class DeleteAccountNotifier extends StateNotifier<AsyncValue<bool>> {
  DeleteAccountNotifier() : super(const AsyncValue.data(false));

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      state = const AsyncValue.loading();

      final result = await SettingsService.deleteAccount();

      if (result['success'] == true) {
        state = const AsyncValue.data(true);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to delete account',
          StackTrace.current,
        );
      }

      return result;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  void reset() {
    state = const AsyncValue.data(false);
  }
}

/// Feedback Provider
final feedbackProvider =
    StateNotifierProvider<FeedbackNotifier, AsyncValue<bool>>((ref) {
  return FeedbackNotifier();
});

class FeedbackNotifier extends StateNotifier<AsyncValue<bool>> {
  FeedbackNotifier() : super(const AsyncValue.data(false));

  Future<Map<String, dynamic>> submitFeedback({
    required String type,
    required String message,
    String? category,
  }) async {
    try {
      state = const AsyncValue.loading();

      final result = await SettingsService.submitFeedback(
        type: type,
        message: message,
        category: category,
      );

      if (result['success'] == true) {
        state = const AsyncValue.data(true);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to submit feedback',
          StackTrace.current,
        );
      }

      return result;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  void reset() {
    state = const AsyncValue.data(false);
  }
}

/// Report Provider
final reportProvider =
    StateNotifierProvider<ReportNotifier, AsyncValue<bool>>((ref) {
  return ReportNotifier();
});

class ReportNotifier extends StateNotifier<AsyncValue<bool>> {
  ReportNotifier() : super(const AsyncValue.data(false));

  Future<Map<String, dynamic>> reportContent({
    required String type,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    try {
      state = const AsyncValue.loading();

      final result = await SettingsService.reportContent(
        type: type,
        targetId: targetId,
        reason: reason,
        description: description,
      );

      if (result['success'] == true) {
        state = const AsyncValue.data(true);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to submit report',
          StackTrace.current,
        );
      }

      return result;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  void reset() {
    state = const AsyncValue.data(false);
  }
}

