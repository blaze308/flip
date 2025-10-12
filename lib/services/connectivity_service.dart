import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  final List<Function(bool)> _listeners = [];

  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _isOnline = !result.contains(ConnectivityResult.none);
      print(
        '📡 ConnectivityService: Initial status - ${_isOnline ? "ONLINE" : "OFFLINE"}',
      );

      // Listen for changes
      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        final wasOnline = _isOnline;
        _isOnline = !results.contains(ConnectivityResult.none);

        if (wasOnline != _isOnline) {
          print(
            '📡 ConnectivityService: Status changed - ${_isOnline ? "ONLINE" : "OFFLINE"}',
          );
          _notifyListeners();
        }
      });

      print('✅ ConnectivityService: Initialized successfully');
    } catch (e) {
      print('❌ ConnectivityService: Failed to initialize: $e');
    }
  }

  void addListener(Function(bool) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(bool) listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener(_isOnline);
      } catch (e) {
        print('❌ ConnectivityService: Error in listener: $e');
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
