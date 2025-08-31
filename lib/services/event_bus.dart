import 'dart:async';

/// Simple event bus for app-wide communication
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final Map<Type, StreamController> _controllers = {};

  /// Get stream for a specific event type
  Stream<T> on<T>() {
    if (!_controllers.containsKey(T)) {
      _controllers[T] = StreamController<T>.broadcast();
    }
    return _controllers[T]!.stream.cast<T>();
  }

  /// Fire an event
  void fire<T>(T event) {
    if (_controllers.containsKey(T)) {
      _controllers[T]!.add(event);
    }
  }

  /// Dispose all controllers
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}

/// Event fired when a new post is created
class PostCreatedEvent {
  final String postId;
  final String postType;

  PostCreatedEvent({required this.postId, required this.postType});
}
