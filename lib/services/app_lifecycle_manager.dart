import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_auth_service.dart';
import 'socket_service.dart';

/// Manages app lifecycle events and background behavior
/// Ensures authentication persistence and socket connections like TikTok/Instagram
class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();

  static AppLifecycleManager get instance => _instance;

  bool _isInitialized = false;
  bool _isInForeground = true;
  DateTime? _lastBackgroundTime;
  Timer? _keepAliveTimer;
  Timer? _onlineStatusTimer;

  // Configuration (keeping for future use and documentation)
  // ignore: unused_field
  static const Duration _backgroundGracePeriod = Duration(
    minutes: 30,
  ); // Like TikTok
  static const Duration _keepAliveInterval = Duration(minutes: 1);
  static const Duration _onlineStatusInterval = Duration(seconds: 30);
  static const Duration _authCheckInterval = Duration(minutes: 5);

  final _lifecycleController = StreamController<AppLifecycleState>.broadcast();
  Stream<AppLifecycleState> get onLifecycleChanged =>
      _lifecycleController.stream;

  /// Initialize lifecycle manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🔄 AppLifecycleManager: Initializing...');

    // Register as lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Start keep-alive timer
    _startKeepAliveTimer();

    // Start online status timer
    _startOnlineStatusTimer();

    // Load last background time
    await _loadLastBackgroundTime();

    _isInitialized = true;
    print('✅ AppLifecycleManager: Initialized successfully');
  }

  /// Clean up resources
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAliveTimer?.cancel();
    _onlineStatusTimer?.cancel();
    _lifecycleController.close();
    _isInitialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('🔄 AppLifecycleManager: Lifecycle state changed to: $state');
    _lifecycleController.add(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        // New in Flutter 3.13+
        _handleAppHidden();
        break;
    }
  }

  /// Handle app resuming from background
  Future<void> _handleAppResumed() async {
    print('📱 AppLifecycleManager: App resumed to foreground');
    _isInForeground = true;

    // Check how long we were in background
    if (_lastBackgroundTime != null) {
      final backgroundDuration = DateTime.now().difference(
        _lastBackgroundTime!,
      );
      print(
        '⏱️ AppLifecycleManager: Was in background for: ${backgroundDuration.inMinutes}m ${backgroundDuration.inSeconds % 60}s',
      );

      // If we were in background for too long, refresh auth
      if (backgroundDuration > _authCheckInterval) {
        print(
          '🔐 AppLifecycleManager: Long background time detected, validating auth...',
        );
        await _validateAndRefreshAuth();
      }
    }

    // Resume keep-alive timer
    _startKeepAliveTimer();

    // Resume online status updates
    _startOnlineStatusTimer();

    // Reconnect socket if disconnected
    await _ensureSocketConnection();

    // Update online status
    await _updateOnlineStatus(true);

    _lastBackgroundTime = null;
  }

  /// Handle app becoming inactive (e.g., system dialog, quick settings)
  void _handleAppInactive() {
    print('📱 AppLifecycleManager: App inactive');
    // Don't disconnect yet - user might come back quickly
  }

  /// Handle app going to background
  Future<void> _handleAppPaused() async {
    print('📱 AppLifecycleManager: App paused (background)');
    _isInForeground = false;
    _lastBackgroundTime = DateTime.now();

    // Save background time
    await _saveLastBackgroundTime();

    // Don't disconnect socket immediately - keep it alive
    // This allows background notifications and messages

    // Slow down keep-alive and online status timers
    _keepAliveTimer?.cancel();
    _onlineStatusTimer?.cancel();

    // Set online status to away (not offline)
    await _updateOnlineStatus(false);

    print('📱 AppLifecycleManager: Background tasks configured');
  }

  /// Handle app being detached (about to be killed)
  Future<void> _handleAppDetached() async {
    print('📱 AppLifecycleManager: App detached');
    _isInForeground = false;

    // Save state before app closes
    await _saveLastBackgroundTime();

    // Set offline status
    await _updateOnlineStatus(false);

    // Clean up
    _keepAliveTimer?.cancel();
    _onlineStatusTimer?.cancel();
  }

  /// Handle app being hidden (new in Flutter 3.13+)
  void _handleAppHidden() {
    print('📱 AppLifecycleManager: App hidden');
    // Similar to paused but might be temporary
  }

  /// Validate and refresh authentication
  Future<void> _validateAndRefreshAuth() async {
    try {
      if (!TokenAuthService.isAuthenticated) {
        print(
          '🔐 AppLifecycleManager: User not authenticated, skipping validation',
        );
        return;
      }

      print('🔐 AppLifecycleManager: Validating authentication...');

      // Try to get fresh auth headers (this will auto-refresh if needed)
      final headers = await TokenAuthService.getAuthHeaders();

      if (headers != null) {
        print('✅ AppLifecycleManager: Authentication valid');
      } else {
        print(
          '❌ AppLifecycleManager: Authentication invalid, user needs to re-login',
        );
        // Don't force logout - let the app handle it gracefully
      }
    } catch (e) {
      print('❌ AppLifecycleManager: Auth validation error: $e');
    }
  }

  /// Ensure socket connection is active
  Future<void> _ensureSocketConnection() async {
    try {
      if (!TokenAuthService.isAuthenticated) {
        print(
          '🔌 AppLifecycleManager: User not authenticated, skipping socket connection',
        );
        return;
      }

      final socketService = SocketService.instance;

      if (!socketService.isConnected) {
        print('🔌 AppLifecycleManager: Socket disconnected, reconnecting...');
        await socketService.connect();
      } else {
        print('✅ AppLifecycleManager: Socket already connected');
      }
    } catch (e) {
      print('❌ AppLifecycleManager: Socket connection error: $e');
    }
  }

  /// Keep-alive timer to maintain background connection
  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();

    if (!TokenAuthService.isAuthenticated) return;

    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (timer) async {
      if (_isInForeground) {
        print('💓 AppLifecycleManager: Keep-alive ping');
        await _ensureSocketConnection();
      }
    });
  }

  /// Online status update timer
  void _startOnlineStatusTimer() {
    _onlineStatusTimer?.cancel();

    if (!TokenAuthService.isAuthenticated) return;

    _onlineStatusTimer = Timer.periodic(_onlineStatusInterval, (timer) async {
      if (_isInForeground) {
        await _updateOnlineStatus(true);
      }
    });
  }

  /// Update user's online status
  Future<void> _updateOnlineStatus(bool isOnline) async {
    try {
      if (!TokenAuthService.isAuthenticated) return;

      final socketService = SocketService.instance;

      if (socketService.isConnected) {
        // Send online status through socket
        socketService.updateOnlineStatus(isOnline);
        print(
          '📡 AppLifecycleManager: Online status updated: ${isOnline ? "online" : "away"}',
        );
      }
    } catch (e) {
      print('❌ AppLifecycleManager: Failed to update online status: $e');
    }
  }

  /// Save last background time to persistent storage
  Future<void> _saveLastBackgroundTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_background_time',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('❌ AppLifecycleManager: Failed to save background time: $e');
    }
  }

  /// Load last background time from persistent storage
  Future<void> _loadLastBackgroundTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('last_background_time');

      if (timestamp != null) {
        _lastBackgroundTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        print(
          '📱 AppLifecycleManager: Last background time loaded: $_lastBackgroundTime',
        );
      }
    } catch (e) {
      print('❌ AppLifecycleManager: Failed to load background time: $e');
    }
  }

  /// Check if app should refresh data based on background time
  bool shouldRefreshData() {
    if (_lastBackgroundTime == null) return false;

    final backgroundDuration = DateTime.now().difference(_lastBackgroundTime!);
    return backgroundDuration > _authCheckInterval;
  }

  /// Getters
  bool get isInForeground => _isInForeground;
  DateTime? get lastBackgroundTime => _lastBackgroundTime;
}
