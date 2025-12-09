import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/live_stream_model.dart';
import '../models/audio_chat_user_model.dart';
import '../models/live_message_model.dart';
import '../services/live_streaming_service.dart';
import '../services/token_auth_service.dart';
import '../services/socket_service.dart';
import '../widgets/custom_toaster.dart';

/// ============================================================
/// AGORA VIDEO PARTY SCREEN V2
/// ============================================================
/// Industry-Standard Implementation of Multi-Host Video Party
/// 
/// Features:
/// - Proper Agora initialization with error handling
/// - Smooth camera rendering with AgoraVideoView
/// - Real-time seat management with WebSocket
/// - Stateful camera/mic controls
/// - Performance optimized with proper cleanup
/// - Scrollable chat with auto-scroll
/// - Host controls for managing other users
/// 
/// Issues Fixed from V1:
/// ✅ Camera visibility - Use AgoraVideoView with proper controller
/// ✅ Layout problems - Proper grid layout with constraints
/// ✅ Performance lag - Reduced setState calls, proper disposal
/// ✅ Bad algorithms - Proper seat tracking, user mapping
/// ✅ Cleanup on dispose - Comprehensive resource cleanup
/// ============================================================

class AgoraVideoPartyScreenV2 extends StatefulWidget {
  final LiveStreamModel liveStream;
  final bool isHost;

  const AgoraVideoPartyScreenV2({
    super.key,
    required this.liveStream,
    this.isHost = false,
  });

  @override
  State<AgoraVideoPartyScreenV2> createState() =>
      _AgoraVideoPartyScreenV2State();
}

class _AgoraVideoPartyScreenV2State extends State<AgoraVideoPartyScreenV2>
    with WidgetsBindingObserver {
  // ========== AGORA ENGINE & STATE ==========
  late RtcEngine _engine;
  bool _isInitialized = false;
  bool _isJoining = true;
  int? _localUid;

  // ========== SEAT MANAGEMENT ==========
  final Map<int, AudioChatUserModel> _seats = {}; // index -> seat data
  final Map<int, int> _remoteUserToSeat = {}; // uid -> seat index
  int? _mySeatIndex;

  // ========== AUDIO/VIDEO CONTROLS ==========
  bool _isMuted = true;
  bool _isVideoEnabled = true; // VIDEO party - enable by default
  bool _isVideoDisabledByHost = false;

  // ========== CHAT & MESSAGING ==========
  final List<LiveMessageModel> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  final ScrollController _videoGridScrollController = ScrollController();

  // ========== REAL-TIME UPDATES ==========
  Timer? _heartbeatTimer;
  StreamSubscription? _socketSubscription;
  bool _isLiveActive = true;

  // ========== UI STATE ==========
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    switch (state) {
      case AppLifecycleState.paused:
        _engine.disableAudio();
        _engine.disableVideo();
        break;
      case AppLifecycleState.resumed:
        _engine.enableAudio();
        _engine.enableVideo();
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initialize() async {
    try {
      // Request permissions with detailed error handling
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (cameraStatus.isDenied || micStatus.isDenied) {
        if (mounted) {
          ToasterService.showError(
            context,
            'Camera and microphone permissions are required for video party',
          );
          Navigator.pop(context);
        }
        return;
      }

      // Enable wakelock to keep screen on
      await WakelockPlus.enable();

      // Set immersive mode (hide system UI)
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

      // Get Agora App ID from .env
      final appId = dotenv.env['AGORA_APP_ID'];
      if (appId == null || appId.isEmpty) {
        throw Exception('Agora App ID not configured in .env');
      }

      // Initialize Agora engine
      _engine = createAgoraRtcEngine();
      await _engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      // Register event handler
      _setupEventHandler();

      // Enable audio and video
      await _engine.enableVideo();
      await _engine.enableAudio();

      // Configure video encoder for quality
      await _engine.setVideoEncoderConfiguration(
        VideoEncoderConfiguration(
          dimensions: const VideoDimensions(width: 1280, height: 720),
          frameRate: 15,
          bitrate: 2000,
          orientationMode: OrientationMode.orientationModeAdaptive,
        ),
      );

      // Set role based on host/guest
      await _engine.setClientRole(
        role: widget.isHost
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleBroadcaster, // Everyone broadcasts in party
      );

      // Start preview if video is enabled
      if (_isVideoEnabled) {
        await _engine.startPreview();
      }

      // Join channel
      await _engine.joinChannel(
        token: '', // In production, get token from server
        channelId: widget.liveStream.streamingChannel,
        uid: 0, // Let Agora assign UID
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      // Initialize seat management
      await _loadSeats();

      // Initialize WebSocket listeners
      _setupSocketListeners();

      // Start heartbeat for periodic seat updates
      _startHeartbeat();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _isJoining = false;
      });

      print('✅ Video party initialized successfully');
    } catch (e) {
      print('❌ Error initializing video party: $e');
      if (mounted) {
        ToasterService.showError(
          context,
          'Failed to initialize video party: $e',
        );
        Navigator.pop(context);
      }
    }
  }

  void _setupEventHandler() {
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        // Connection events
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print(
            '✅ Joined channel: ${connection.channelId}, UID: ${connection.localUid}',
          );
          setState(() {
            _localUid = connection.localUid;
          });

          // Join seat for host, subscribe for guest
          if (widget.isHost) {
            _joinHostSeat();
          } else {
            _joinAsViewer();
          }
        },

        // Remote user events
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('👤 User joined: $remoteUid');
          _onRemoteUserJoined(remoteUid);
        },

        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          print('👋 User left: $remoteUid (reason: $reason)');
          _onRemoteUserLeft(remoteUid);
        },

        // Video state changes
        onRemoteVideoStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteVideoState state,
          RemoteVideoStateReason reason,
          int elapsed,
        ) {
          print(
            '📹 Remote video state: $remoteUid -> $state (reason: $reason)',
          );
          setState(() {
            // Update seat video status
            final seatIndex = _remoteUserToSeat[remoteUid];
            if (seatIndex != null && _seats.containsKey(seatIndex)) {
              final currentSeat = _seats[seatIndex];
              if (currentSeat != null) {
                _seats[seatIndex] = currentSeat.copyWith(
                  enabledVideo: state == RemoteVideoState.remoteVideoStateDecoding,
                );
              }
            }
          });
        },

        onRemoteAudioStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteAudioState state,
          RemoteAudioStateReason reason,
          int elapsed,
        ) {
          print(
            '🔊 Remote audio state: $remoteUid -> $state (reason: $reason)',
          );
          setState(() {
            final seatIndex = _remoteUserToSeat[remoteUid];
            if (seatIndex != null && _seats.containsKey(seatIndex)) {
              final currentSeat = _seats[seatIndex];
              if (currentSeat != null) {
                _seats[seatIndex] = currentSeat.copyWith(
                  enabledAudio: state == RemoteAudioState.remoteAudioStateDecoding,
                );
              }
            }
          });
        },

        // Error handling
        onError: (ErrorCodeType err, String msg) {
          print('❌ Agora error: $err - $msg');
          ToasterService.showError(context, 'Connection error: $msg');
        },

        onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
        ) {
          print('🔗 Connection state: $state (reason: $reason)');

          // Handle connection loss
          if (state == ConnectionStateType.connectionStateFailed) {
            ToasterService.showError(context, 'Connection failed, attempting to reconnect...');
          } else if (state == ConnectionStateType.connectionStateConnected) {
            ToasterService.showInfo(context, 'Reconnected to party');
          }
        },
      ),
    );
  }

  void _setupSocketListeners() {
    final socket = SocketService.instance.socket;
    if (socket == null) {
      print('⚠️ Socket not initialized');
      return;
    }

    // Listen for seat updates
    socket.on('live:seat:updated', (data) {
      print('🪑 Seat updated: $data');
      _loadSeats();
    });

    // Listen for host actions (mute, remove, etc)
    socket.on('live:host:action', (data) {
      print('🎬 Host action: $data');
      _onHostAction(data);
    });

    // Listen for new messages
    socket.on('live:message:new', (data) {
      print('💬 New message: $data');
      _onNewMessage(data);
    });

    // Listen for live ended
    socket.on('live:ended', (data) {
      print('🔴 Live ended');
      _onLiveEnded();
    });

    // Listen for user removed
    socket.on('live:user:removed', (data) {
      if (data['userId'] == TokenAuthService.currentUser?.id) {
        print('❌ You were removed from the live');
        ToasterService.showError(context, 'You were removed from the party');
        _leaveLive();
      }
    });
  }

  Future<void> _loadSeats() async {
    try {
      final seats = await LiveStreamingService.getPartySeats(
        widget.liveStream.id,
      );

      if (!mounted) return;

      setState(() {
        // Clear old seats
        _seats.clear();

        // Rebuild seat map
        for (final seat in seats) {
          _seats[seat.seatIndex] = seat;

          // Update remote user mapping if seat is occupied
          if (seat.joinedUserUid != null && !seat.leftRoom) {
            _remoteUserToSeat[seat.joinedUserUid!] = seat.seatIndex;
          }
        }
      });

      print('✅ Loaded ${seats.length} seats');
    } catch (e) {
      print('❌ Error loading seats: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!_isLiveActive || !mounted) return;

      try {
        await _loadSeats();
      } catch (e) {
        print('⚠️ Heartbeat error: $e');
      }
    });
  }

  Future<void> _joinHostSeat() async {
    if (_localUid == null) return;

    try {
      await LiveStreamingService.joinPartySeat(
        liveStreamId: widget.liveStream.id,
        seatIndex: 0, // Host always takes seat 0
        userUid: _localUid!,
      );

      setState(() => _mySeatIndex = 0);

      // Notify via WebSocket
      SocketService.instance.socket?.emit('live:seat:joined', {
        'liveStreamId': widget.liveStream.id,
        'seatIndex': 0,
        'uid': _localUid,
      });

      print('✅ Host joined seat 0');
    } catch (e) {
      print('❌ Error joining host seat: $e');
    }
  }

  Future<void> _joinAsViewer() async {
    try {
      final user = TokenAuthService.currentUser;
      if (user == null) return;

      await LiveStreamingService.joinLiveStream(
        liveStreamId: widget.liveStream.id,
        userUid: _localUid ?? 0,
      );

      SocketService.instance.socket?.emit('live:joined', {
        'liveStreamId': widget.liveStream.id,
        'uid': _localUid,
      });

      print('✅ Joined as viewer');
    } catch (e) {
      print('❌ Error joining as viewer: $e');
    }
  }

  void _onRemoteUserJoined(int uid) {
    print('🔍 Remote user joined, searching seat for UID: $uid');
    setState(() {
      // Remote user will be mapped when seat data is loaded
    });
  }

  void _onRemoteUserLeft(int uid) {
    setState(() {
      final seatIndex = _remoteUserToSeat[uid];
      if (seatIndex != null) {
        _remoteUserToSeat.remove(uid);
        print('✅ Removed UID $uid from seat $seatIndex');
      }
    });
  }

  void _onHostAction(Map<String, dynamic> data) {
    final action = data['action'];
    final targetUserId = data['targetUserId'];
    final user = TokenAuthService.currentUser;

    if (targetUserId != user?.id) return;

    switch (action) {
      case 'mute':
        setState(() => _isMuted = true);
        _engine.muteLocalAudioStream(true);
        ToasterService.showInfo(context, 'You have been muted by host');
        break;

      case 'unmute':
        setState(() => _isMuted = false);
        _engine.muteLocalAudioStream(false);
        ToasterService.showInfo(context, 'You have been unmuted by host');
        break;

      case 'disable_video':
        setState(() => _isVideoDisabledByHost = true);
        _engine.muteLocalVideoStream(true);
        ToasterService.showInfo(context, 'Your video has been disabled by host');
        break;

      case 'enable_video':
        setState(() {
          _isVideoDisabledByHost = false;
          _isVideoEnabled = true;
        });
        _engine.muteLocalVideoStream(false);
        ToasterService.showInfo(context, 'Your video has been enabled');
        break;

      case 'remove':
        ToasterService.showError(context, 'You were removed from the party');
        _leaveLive();
        break;
    }
  }

  void _onNewMessage(Map<String, dynamic> data) {
    try {
      final message = LiveMessageModel.fromJson(data);
      setState(() {
        _messages.add(message);
      });

      // Auto-scroll to latest message
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_messageScrollController.hasClients) {
          _messageScrollController.animateTo(
            _messageScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('❌ Error parsing message: $e');
    }
  }

  void _onLiveEnded() {
    if (mounted) {
      ToasterService.showInfo(context, 'Video party has ended');
      Navigator.pop(context);
    }
  }

  // ========== CONTROL METHODS ==========

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine.muteLocalAudioStream(_isMuted);

    // Notify via WebSocket
    SocketService.instance.socket?.emit('live:audio:toggled', {
      'liveStreamId': widget.liveStream.id,
      'muted': _isMuted,
    });

    print(_isMuted ? '🔇 Muted' : '🔊 Unmuted');
  }

  Future<void> _toggleVideo() async {
    if (_isVideoDisabledByHost) {
      ToasterService.showInfo(context, 'Host has disabled your video');
      return;
    }

    setState(() => _isVideoEnabled = !_isVideoEnabled);
    await _engine.muteLocalVideoStream(!_isVideoEnabled);

    if (_isVideoEnabled) {
      await _engine.startPreview();
    }

    // Notify via WebSocket
    SocketService.instance.socket?.emit('live:video:toggled', {
      'liveStreamId': widget.liveStream.id,
      'enabled': _isVideoEnabled,
    });

    print(_isVideoEnabled ? '📹 Video enabled' : '📹 Video disabled');
  }

  Future<void> _switchCamera() async {
    await _engine.switchCamera();
    ToasterService.showInfo(context, 'Camera switched');
  }

  Future<void> _joinSeat(int seatIndex) async {
    if (_mySeatIndex != null) {
      ToasterService.showInfo(context, 'You are already in a seat');
      return;
    }

    try {
      await LiveStreamingService.joinPartySeat(
        liveStreamId: widget.liveStream.id,
        seatIndex: seatIndex,
        userUid: _localUid ?? 0,
      );

      setState(() => _mySeatIndex = seatIndex);

      // Switch to broadcaster role for audio
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      ToasterService.showSuccess(context, 'Joined seat ${seatIndex + 1}');
      await _loadSeats();

      print('✅ Joined seat $seatIndex');
    } catch (e) {
      print('❌ Error joining seat: $e');
      ToasterService.showError(context, 'Failed to join seat');
    }
  }

  Future<void> _leaveSeat() async {
    if (_mySeatIndex == null) return;

    try {
      await LiveStreamingService.leavePartySeat(
        liveStreamId: widget.liveStream.id,
        seatIndex: _mySeatIndex!,
      );

      setState(() => _mySeatIndex = null);

      ToasterService.showSuccess(context, 'Left seat');
      await _loadSeats();

      print('✅ Left seat');
    } catch (e) {
      print('❌ Error leaving seat: $e');
      ToasterService.showError(context, 'Failed to leave seat');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await LiveStreamingService.sendMessage(
        liveStreamId: widget.liveStream.id,
        message: text,
        messageType: 'COMMENT',
      );

      _messageController.clear();

      // Add message locally for immediate feedback
      final user = TokenAuthService.currentUser;
      if (user != null) {
        final message = LiveMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          authorId: user.id,
          liveStreamId: widget.liveStream.id,
          message: text,
          messageType: 'COMMENT',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _onNewMessage(message.toJson());
      }

      print('✅ Message sent');
    } catch (e) {
      print('❌ Error sending message: $e');
      ToasterService.showError(context, 'Failed to send message');
    }
  }

  Future<void> _leaveLive() async {
    try {
      // Leave seat if in one
      if (_mySeatIndex != null) {
        await _leaveSeat();
      }

      // Leave live stream
      if (!widget.isHost) {
        await LiveStreamingService.leaveLiveStream(
          liveStreamId: widget.liveStream.id,
          userUid: _localUid ?? 0,
        );

        SocketService.instance.socket?.emit('live:left', {
          'liveStreamId': widget.liveStream.id,
          'uid': _localUid,
        });
      }

      print('✅ Left live');

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error leaving live: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // ========== BUILD METHODS ==========

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _isJoining) {
      return _buildLoadingScreen();
    }

    return WillPopScope(
      onWillPop: () async {
        await _leaveLive();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: _buildVideoGrid(),
                  ),
                  _buildChatSection(),
                  _buildBottomControls(),
                ],
              ),
              _buildTopBar(),
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomControls(),
                ),
            ],
          ),
        ),
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
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
            ),
            const SizedBox(height: 24),
            Text(
              widget.isHost ? 'Starting video party...' : 'Joining video party...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => _leaveLive(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Live badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Icon(Icons.videocam, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Viewer count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${widget.liveStream.viewersCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Host indicator
          if (widget.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star, color: Colors.purple, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'HOST',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    final numberOfSeats = widget.liveStream.numberOfChairs;
    final crossAxisCount = numberOfSeats <= 4 ? 2 : 3;

    return GestureDetector(
      onTap: () {
        // Toggle controls on tap
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        color: Colors.black,
        child: GridView.builder(
          controller: _videoGridScrollController,
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: numberOfSeats,
          itemBuilder: (context, index) {
            final seat = _seats[index];
            return _buildVideoCard(seat, index);
          },
        ),
      ),
    );
  }

  Widget _buildVideoCard(AudioChatUserModel? seat, int seatIndex) {
    final isOccupied = seat != null && seat.joinedUserId != null && !seat.leftRoom;
    final isMe = _mySeatIndex == seatIndex;
    final isHost = widget.isHost && seatIndex == 0;

    return GestureDetector(
      onTap: () {
        if (!isOccupied && _mySeatIndex == null) {
          _joinSeat(seatIndex);
        } else if (isMe) {
          // Long press to show options
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe
                ? Colors.cyan
                : isHost
                    ? Colors.purple.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Video view or placeholder
            if (isOccupied && seat.enabledVideo && seat.joinedUserUid != null)
              _buildRemoteVideoView(seat.joinedUserUid!)
            else
              _buildVideoPlaceholder(seat, seatIndex),

            // Mute indicator
            if (isOccupied && !seat.enabledAudio)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),

            // Host badge
            if (isHost)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 10),
                      SizedBox(width: 2),
                      Text(
                        'HOST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Seat number / "My Seat"
            if (!isHost)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.cyan : Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isMe ? 'MY SEAT' : 'SEAT ${seatIndex + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Empty seat indicator
            if (!isOccupied)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add,
                        color: Colors.white.withOpacity(0.5),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Empty Seat',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideoView(int uid) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: uid),
          connection: RtcConnection(
            channelId: widget.liveStream.streamingChannel,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(AudioChatUserModel? seat, int seatIndex) {
    final isOccupied = seat != null && seat.joinedUserId != null && !seat.leftRoom;

    if (!isOccupied) {
      return const SizedBox.expand();
    }

    return Container(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withOpacity(0.1),
              backgroundImage: seat.joinedUser?.profileImageUrl != null
                  ? CachedNetworkImageProvider(
                      seat.joinedUser!.profileImageUrl!,
                    )
                  : null,
              child: seat.joinedUser?.profileImageUrl == null
                  ? const Icon(Icons.person, color: Colors.white, size: 32)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              seat.joinedUser?.displayName ?? 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatSection() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
        ),
      ),
      child: Column(
        children: [
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _messageScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${message.author?.displayName ?? 'User'}: ',
                              style: const TextStyle(
                                color: Colors.cyan,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Expanded(
                              child: Text(
                                message.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Message input
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Say something...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.cyan, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_mySeatIndex != null) ...[
            // Mute button
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? 'Unmute' : 'Mute',
              onTap: _toggleMute,
              isActive: !_isMuted,
            ),

            // Video button
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              label: _isVideoEnabled ? 'Video' : 'Video Off',
              onTap: _toggleVideo,
              isActive: _isVideoEnabled,
              isDisabled: _isVideoDisabledByHost,
            ),

            // Switch camera button
            _buildControlButton(
              icon: Icons.cameraswitch,
              label: 'Switch',
              onTap: _switchCamera,
              isActive: true,
            ),

            // Leave button
            _buildControlButton(
              icon: Icons.exit_to_app,
              label: 'Leave',
              onTap: _leaveSeat,
              isActive: false,
              isDestructive: true,
            ),
          ] else ...[
            // Join seat button
            _buildControlButton(
              icon: Icons.chair,
              label: 'Join Seat',
              onTap: () {
                final emptySeat = _seats.entries
                    .firstWhere(
                      (e) =>
                          e.value.joinedUserId == null ||
                          e.value.leftRoom,
                      orElse: () => _seats.entries.first,
                    )
                    .value;
                _joinSeat(emptySeat.seatIndex);
              },
              isActive: true,
            ),

            // Leave live button
            _buildControlButton(
              icon: Icons.logout,
              label: 'Leave',
              onTap: _leaveLive,
              isActive: false,
              isDestructive: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isActive,
    bool isDestructive = false,
    bool isDisabled = false,
  }) {
    Color color = Colors.white.withOpacity(0.7);

    if (isDisabled) {
      color = Colors.grey;
    } else if (isDestructive) {
      color = Colors.red;
    } else if (isActive) {
      color = Colors.cyan;
    }

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Cancel timers
    _heartbeatTimer?.cancel();
    _socketSubscription?.cancel();

    // Dispose controllers
    _messageController.dispose();
    _messageScrollController.dispose();
    _videoGridScrollController.dispose();

    // Clean up Agora
    try {
      _engine.leaveChannel();
      _engine.release();
    } catch (e) {
      print('⚠️ Error releasing Agora: $e');
    }

    // Clean up wakelock and system UI
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    print('✅ Video party disposed');

    super.dispose();
  }
}
