import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'socket_service.dart';
import '../screens/live/incoming_call_screen.dart';

/// Global manager for handling incoming call notifications
class IncomingCallManager {
  static final IncomingCallManager _instance = IncomingCallManager._internal();
  factory IncomingCallManager() => _instance;
  IncomingCallManager._internal();

  BuildContext? _context;
  StreamSubscription? _callInvitationSubscription;
  bool _isShowingIncomingCall = false;

  /// Initialize the incoming call manager with app context
  void initialize(BuildContext context) {
    _context = context;
    _setupCallListener();
  }

  /// Setup listener for incoming calls
  void _setupCallListener() {
    _callInvitationSubscription?.cancel();

    _callInvitationSubscription = SocketService.instance.onCallInvitation
        .listen((invitation) {
          print('📞 IncomingCallManager: Received call invitation');
          _showIncomingCallScreen(invitation);
        });
  }

  /// Show incoming call screen
  void _showIncomingCallScreen(CallInvitationEvent invitation) {
    if (_context == null || _isShowingIncomingCall) {
      print(
        '📞 IncomingCallManager: Cannot show incoming call (context null or already showing)',
      );
      return;
    }

    _isShowingIncomingCall = true;

    // Use WidgetsBinding to ensure navigation happens after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_context != null && _isShowingIncomingCall) {
        Navigator.of(_context!)
            .push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder:
                    (context) => IncomingCallScreen(invitation: invitation),
              ),
            )
            .then((_) {
              _isShowingIncomingCall = false;
            });
      }
    });
  }

  /// Update context (call this when navigating to main screens)
  void updateContext(BuildContext context) {
    _context = context;
  }

  /// Dispose and cleanup
  void dispose() {
    _callInvitationSubscription?.cancel();
    _context = null;
  }
}
