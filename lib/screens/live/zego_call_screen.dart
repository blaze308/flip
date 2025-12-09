import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../services/zego_call_service.dart';
import '../../services/token_auth_service.dart';
import '../../widgets/custom_toaster.dart';

class ZegoCallScreen extends StatefulWidget {
  final String callId;
  final String recipientName;
  final String? recipientAvatar;
  final bool isAudioOnly;
  final bool isIncoming;

  const ZegoCallScreen({
    super.key,
    required this.callId,
    required this.recipientName,
    this.recipientAvatar,
    this.isAudioOnly = false,
    this.isIncoming = false,
  });

  @override
  State<ZegoCallScreen> createState() => _ZegoCallScreenState();
}

class _ZegoCallScreenState extends State<ZegoCallScreen> {
  String _status = 'Connecting...';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    WakelockPlus.enable();
    _joinCall();
  }

  Future<void> _joinCall() async {
    try {
      setState(() {
        _status = widget.isIncoming ? 'Connecting...' : 'Calling...';
      });

      // Get user info - must be authenticated to make calls
      final user = TokenAuthService.currentUser;
      if (user == null) {
        print('❌ ZegoCallScreen: User not authenticated');
        if (mounted) {
          ToasterService.showError(context, 'Authentication required');
          Navigator.pop(context);
        }
        return;
      }

      final userID = user.id; // Use id directly, never null here
      final userName = user.displayName ?? user.email ?? 'Flip User';

      print('📞 ZegoCallScreen: Joining call...');
      print('   Call ID: ${widget.callId}');
      print('   User: $userName');
      print('   Audio Only: ${widget.isAudioOnly}');

      // Small delay to show loading screen
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Navigate to ZegoCloud call
      if (widget.isAudioOnly) {
        await ZegoCallService.startAudioCall(
          context: context,
          callID: widget.callId,
          userID: userID,
          userName: userName,
          recipientName: widget.recipientName,
        );
      } else {
        await ZegoCallService.startVideoCall(
          context: context,
          callID: widget.callId,
          userID: userID,
          userName: userName,
          recipientName: widget.recipientName,
        );
      }

      // Call ended, go back
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ ZegoCallScreen: Error joining call: $e');
      if (mounted) {
        ToasterService.showError(context, 'Failed to join call');
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while joining
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF25D366).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child:
                        widget.recipientAvatar != null
                            ? CircleAvatar(
                              radius: 60,
                              backgroundImage: NetworkImage(
                                widget.recipientAvatar!,
                              ),
                            )
                            : Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF075E54),
                              ),
                              child: Center(
                                child: Text(
                                  widget.recipientName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                  ),
                  const SizedBox(height: 30),

                  // Recipient name
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status
                  Text(
                    _status,
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  const SizedBox(height: 30),

                  // Loading indicator
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF25D366),
                    ),
                  ),
                ],
              ),
            ),

            // Back button
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
