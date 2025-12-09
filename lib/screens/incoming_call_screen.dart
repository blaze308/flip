import 'package:flutter/material.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/call_service.dart';
import 'zego_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallInvitationEvent invitation;

  const IncomingCallScreen({super.key, required this.invitation});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timeoutTimer;
  bool _isAnswering = false;
  bool _isRejecting = false;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Auto-dismiss after 30 seconds
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isAnswering && !_isRejecting) {
        _rejectCall();
      }
    });

    // Listen for call ended event
    SocketService.instance.onCallEnded.listen((event) {
      if (event.callId == widget.invitation.callId && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _answerCall() async {
    if (_isAnswering || _isRejecting) return;

    setState(() {
      _isAnswering = true;
    });

    try {
      // Navigate to Jitsi call screen
      if (mounted) {
        Navigator.of(context).pop(); // Close incoming call screen

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ZegoCallScreen(
                  callId: widget.invitation.callId,
                  recipientName: widget.invitation.callerName,
                  recipientAvatar: widget.invitation.callerAvatar,
                  isAudioOnly: widget.invitation.type != 'video',
                  isIncoming: true,
                ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error answering call: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to answer call: $e')));
      }
    }
  }

  Future<void> _rejectCall() async {
    if (_isRejecting || _isAnswering) return;

    setState(() {
      _isRejecting = true;
    });

    try {
      await CallService.rejectCall(widget.invitation.callId);
    } catch (e) {
      print('❌ Error rejecting call: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.invitation.type == 'video';

    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Incoming ${isVideoCall ? 'Video' : 'Audio'} Call',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar with pulse animation
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF25D366).withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child:
                          widget.invitation.callerAvatar != null
                              ? CircleAvatar(
                                radius: 80,
                                backgroundImage: NetworkImage(
                                  widget.invitation.callerAvatar!,
                                ),
                              )
                              : Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF075E54),
                                ),
                                child: Center(
                                  child: Text(
                                    widget.invitation.callerName[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 64,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Caller name
                  Text(
                    widget.invitation.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Call type
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isVideoCall ? Icons.videocam : Icons.phone,
                        color: const Color(0xFF25D366),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isVideoCall ? 'Video' : 'Audio'} Call',
                        style: TextStyle(color: Colors.grey[400], fontSize: 18),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Ringing indicator
                  Text(
                    'Ringing...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap:
                            _isAnswering || _isRejecting ? null : _rejectCall,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: _isRejecting ? Colors.grey[700] : Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child:
                              _isRejecting
                                  ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.call_end,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Decline',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),

                  // Answer button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap:
                            _isAnswering || _isRejecting ? null : _answerCall,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color:
                                _isAnswering
                                    ? Colors.grey[700]
                                    : const Color(0xFF25D366),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366).withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child:
                              _isAnswering
                                  ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Icon(
                                    isVideoCall ? Icons.videocam : Icons.phone,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Accept',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
