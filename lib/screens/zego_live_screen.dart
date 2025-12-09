import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'dart:async';
import '../models/live_stream_model.dart';
import '../services/live_streaming_service.dart';
import '../services/token_auth_service.dart';
import '../services/socket_service.dart';
import '../widgets/custom_toaster.dart';

/// ZegoCloud Live Streaming Screen
/// Handles both host (broadcaster) and viewer modes
/// Features: Live video/audio, built-in chat, gifts, viewer count
class ZegoLiveScreen extends StatefulWidget {
  final LiveStreamModel liveStream;
  final bool isHost;

  const ZegoLiveScreen({
    super.key,
    required this.liveStream,
    this.isHost = false,
  });

  @override
  State<ZegoLiveScreen> createState() => _ZegoLiveScreenState();
}

class _ZegoLiveScreenState extends State<ZegoLiveScreen> {
  late int appID;
  late String appSign;
  late String liveID;
  late String userID;
  late String userName;

  bool _isJoining = true;
  bool _hasJoined = false;
  Timer? _heartbeatTimer;
  StreamSubscription? _liveEndSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLive();
  }

  Future<void> _initializeLive() async {
    try {
      // Get ZegoCloud credentials
      final appIdStr = dotenv.env['ZEGO_APP_ID'];
      final appSignStr = dotenv.env['ZEGO_APP_SIGN'];

      if (appIdStr == null || appSignStr == null) {
        throw Exception('ZegoCloud credentials not found in .env file');
      }

      appID = int.parse(appIdStr);
      appSign = appSignStr;

      // Get user info
      final user = TokenAuthService.currentUser;
      if (user == null) {
        if (mounted) {
          ToasterService.showError(context, 'Authentication required');
          Navigator.pop(context);
        }
        return;
      }

      userID = user.id;
      userName = user.displayName ?? user.email ?? 'User';
      liveID = widget.liveStream.streamingChannel;

      // Enable wakelock
      await WakelockPlus.enable();

      // Set immersive mode
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

      // Join the live stream
      if (!widget.isHost) {
        await _joinAsViewer();
      }

      // Listen for live end events via Socket.IO
      _listenForLiveEnd();

      // Start heartbeat to keep viewer count updated
      _startHeartbeat();

      setState(() {
        _isJoining = false;
        _hasJoined = true;
      });
    } catch (e) {
      print('❌ Error initializing live: $e');
      if (mounted) {
        ToasterService.showError(context, 'Failed to join live');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _joinAsViewer() async {
    try {
      // Get user UID for backend
      final user = TokenAuthService.currentUser;
      if (user == null) return;

      // Join via backend API
      await LiveStreamingService.joinLiveStream(
        liveStreamId: widget.liveStream.id,
        userUid: int.parse(user.id.hashCode.toString().substring(0, 8)),
      );

      // Join Socket.IO room for real-time updates
      SocketService.instance.socket?.emit('live:join', {
        'liveStreamId': widget.liveStream.id,
      });

      print('✅ Joined live stream as viewer');
    } catch (e) {
      print('❌ Error joining as viewer: $e');
    }
  }

  void _listenForLiveEnd() {
    final socket = SocketService.instance.socket;
    if (socket == null) return;

    socket.on('live:ended', (data) {
      if (data['liveStreamId'] == widget.liveStream.id) {
        _onLiveEnded();
      }
    });
  }

  void _startHeartbeat() {
    // Send heartbeat every 30 seconds to keep viewer count accurate
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasJoined && !widget.isHost) {
        // Refresh live stream data
        _refreshLiveData();
      }
    });
  }

  Future<void> _refreshLiveData() async {
    try {
      await LiveStreamingService.getLiveStreamDetails(widget.liveStream.id);
      // Live data refreshed (ZegoCloud handles UI updates automatically)
    } catch (e) {
      print('❌ Error refreshing live data: $e');
    }
  }

  void _onLiveEnded() {
    if (mounted) {
      ToasterService.showInfo(context, 'Live stream has ended');
      Navigator.pop(context);
    }
  }

  Future<void> _leaveLive() async {
    try {
      if (!widget.isHost && _hasJoined) {
        final user = TokenAuthService.currentUser;
        if (user != null) {
          // Leave via backend API
          await LiveStreamingService.leaveLiveStream(
            liveStreamId: widget.liveStream.id,
            userUid: int.parse(user.id.hashCode.toString().substring(0, 8)),
          );

          // Leave Socket.IO room
          SocketService.instance.socket?.emit('live:leave', {
            'liveStreamId': widget.liveStream.id,
          });
        }
      }
    } catch (e) {
      print('❌ Error leaving live: $e');
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _liveEndSubscription?.cancel();
    _leaveLive();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isJoining) {
      return _buildLoadingScreen();
    }

    return SafeArea(
      child: ZegoUIKitPrebuiltLiveStreaming(
        appID: appID,
        appSign: appSign,
        userID: userID,
        userName: userName,
        liveID: liveID,
        config:
            widget.isHost
                ? ZegoUIKitPrebuiltLiveStreamingConfig.host()
                : ZegoUIKitPrebuiltLiveStreamingConfig.audience(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4ECDC4).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child:
                  widget.liveStream.author?.profileImageUrl != null
                      ? CircleAvatar(
                        radius: 60,
                        backgroundImage: NetworkImage(
                          widget.liveStream.author!.profileImageUrl!,
                        ),
                      )
                      : Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2A2A2A),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                      ),
            ),
            const SizedBox(height: 30),
            Text(
              widget.liveStream.author?.displayName ?? 'Live Stream',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isHost ? 'Starting live...' : 'Joining live...',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
            ),
          ],
        ),
      ),
    );
  }
}
