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

/// Agora Video Party Screen
/// Multi-host VIDEO conferencing room with seats
/// Features: Multiple video feeds, seat management, host controls, real-time chat
/// STRICTLY VIDEO - Users must have video enabled
class AgoraVideoPartyScreen extends StatefulWidget {
  final LiveStreamModel liveStream;
  final bool isHost;

  const AgoraVideoPartyScreen({
    super.key,
    required this.liveStream,
    this.isHost = false,
  });

  @override
  State<AgoraVideoPartyScreen> createState() => _AgoraVideoPartyScreenState();
}

class _AgoraVideoPartyScreenState extends State<AgoraVideoPartyScreen> {
  late RtcEngine _engine;
  List<AudioChatUserModel> _seats = [];
  List<LiveMessageModel> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  bool _isInitialized = false;
  bool _isJoining = true;
  bool _isMuted = true;
  bool _isVideoEnabled = true; // VIDEO PARTY - Video ON by default
  int? _localUid;
  int? _mySeatIndex;
  Map<int, int> _remoteUsers = {}; // uid -> seatIndex

  Timer? _heartbeatTimer;
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    try {
      // Request permissions - Camera optional, mic required
      await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (micStatus.isDenied) {
        if (mounted) {
          ToasterService.showError(
            context,
            'Microphone permission required for video party',
          );
          Navigator.pop(context);
        }
        return;
      }

      await WakelockPlus.enable();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

      final appId = dotenv.env['AGORA_APP_ID'];

      if (appId == null || appId.isEmpty) {
        throw Exception('Agora App ID not found in .env file');
      }

      _engine = createAgoraRtcEngine();
      await _engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print('✅ Joined VIDEO party: ${connection.channelId}');
            setState(() {
              _localUid = connection.localUid;
              _isJoining = false;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            print('👤 User joined VIDEO party: $remoteUid');
            _onUserJoined(remoteUid);
          },
          onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            print('👋 User left VIDEO party: $remoteUid');
            _onUserLeft(remoteUid);
          },
          onError: (ErrorCodeType err, String msg) {
            print('❌ Agora error: $err - $msg');
          },
        ),
      );

      // ENABLE VIDEO - This is a VIDEO party (but video is optional)
      await _engine.enableVideo();
      await _engine.enableAudio();

      // Start with video OFF by default, user can enable it
      setState(() => _isVideoEnabled = false);
      await _engine.muteLocalVideoStream(true);

      if (widget.isHost) {
        await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      } else {
        await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      }

      await _engine.joinChannel(
        token: '',
        channelId: widget.liveStream.streamingChannel,
        uid: 0,
        options: const ChannelMediaOptions(),
      );

      await _loadSeats();

      if (!widget.isHost) {
        await _joinAsViewer();
      }

      _listenForSocketEvents();
      _startHeartbeat();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('❌ Error initializing VIDEO party: $e');
      if (mounted) {
        ToasterService.showError(context, 'Failed to initialize video party');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadSeats() async {
    try {
      final seats = await LiveStreamingService.getPartySeats(
        widget.liveStream.id,
      );

      if (mounted) {
        setState(() {
          _seats = seats;
        });
      }
    } catch (e) {
      print('❌ Error loading seats: $e');
    }
  }

  Future<void> _joinAsViewer() async {
    try {
      final user = TokenAuthService.currentUser;
      if (user == null) return;

      await LiveStreamingService.joinLiveStream(
        liveStreamId: widget.liveStream.id,
        userUid: int.parse(user.id.hashCode.toString().substring(0, 8)),
      );

      SocketService.instance.socket?.emit('live:join', {
        'liveStreamId': widget.liveStream.id,
      });

      print('✅ Joined VIDEO party as viewer');
    } catch (e) {
      print('❌ Error joining as viewer: $e');
    }
  }

  void _listenForSocketEvents() {
    final socket = SocketService.instance.socket;
    if (socket == null) return;

    socket.on('live:ended', (data) {
      if (data['liveStreamId'] == widget.liveStream.id) {
        _onLiveEnded();
      }
    });

    socket.on('live:seat:update', (data) {
      _onSeatUpdate(data);
    });

    socket.on('live:host:action', (data) {
      _onHostAction(data);
    });

    socket.on('live:message', (data) {
      _onNewMessage(data);
    });
  }

  void _onUserJoined(int uid) {
    setState(() {
      final seat = _seats.firstWhere(
        (s) => s.joinedUserUid == uid,
        orElse: () => _seats.first,
      );
      _remoteUsers[uid] = seat.seatIndex;
    });
  }

  void _onUserLeft(int uid) {
    setState(() {
      _remoteUsers.remove(uid);
    });
  }

  void _onSeatUpdate(Map<String, dynamic> data) {
    _loadSeats();
  }

  void _onHostAction(Map<String, dynamic> data) {
    final action = data['action'];
    final user = TokenAuthService.currentUser;

    if (data['targetUserId'] == user?.id) {
      switch (action) {
        case 'muted':
          setState(() => _isMuted = true);
          _engine.muteLocalAudioStream(true);
          ToasterService.showInfo(context, 'You have been muted by host');
          break;
        case 'unmuted':
          setState(() => _isMuted = false);
          _engine.muteLocalAudioStream(false);
          ToasterService.showInfo(context, 'You have been unmuted by host');
          break;
        case 'video_disabled':
          setState(() => _isVideoEnabled = false);
          _engine.muteLocalVideoStream(true);
          ToasterService.showInfo(
            context,
            'Your video has been disabled by host',
          );
          break;
        case 'removed':
          ToasterService.showError(
            context,
            'You have been removed from the video party',
          );
          Navigator.pop(context);
          break;
      }
    }
  }

  void _onNewMessage(Map<String, dynamic> data) {
    final message = LiveMessageModel.fromJson(data['message']);
    setState(() {
      _messages.add(message);
    });

    if (_messageScrollController.hasClients) {
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onLiveEnded() {
    if (mounted) {
      ToasterService.showInfo(context, 'Video party has ended');
      Navigator.pop(context);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadSeats();
    });
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine.muteLocalAudioStream(_isMuted);
  }

  Future<void> _toggleVideo() async {
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    await _engine.muteLocalVideoStream(!_isVideoEnabled);
  }

  Future<void> _switchCamera() async {
    await _engine.switchCamera();
  }

  Future<void> _joinSeat(int seatIndex) async {
    try {
      final user = TokenAuthService.currentUser;
      if (user == null) return;

      await LiveStreamingService.joinPartySeat(
        liveStreamId: widget.liveStream.id,
        seatIndex: seatIndex,
        userUid: _localUid ?? 0,
      );

      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Join seat with video OFF by default (user can enable)
      setState(() {
        _mySeatIndex = seatIndex;
        _isVideoEnabled = false;
      });
      await _engine.muteLocalVideoStream(true);

      ToasterService.showSuccess(context, 'Joined seat $seatIndex');
      await _loadSeats();
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

      await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);

      setState(() {
        _mySeatIndex = null;
        _isVideoEnabled = false;
      });

      ToasterService.showSuccess(context, 'Left seat');
      await _loadSeats();
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
    } catch (e) {
      print('❌ Error sending message: $e');
      ToasterService.showError(context, 'Failed to send message');
    }
  }

  Future<void> _leaveLive() async {
    try {
      if (_mySeatIndex != null) {
        await _leaveSeat();
      }

      final user = TokenAuthService.currentUser;
      if (user != null && !widget.isHost) {
        await LiveStreamingService.leaveLiveStream(
          liveStreamId: widget.liveStream.id,
          userUid: int.parse(user.id.hashCode.toString().substring(0, 8)),
        );

        SocketService.instance.socket?.emit('live:leave', {
          'liveStreamId': widget.liveStream.id,
        });
      }
    } catch (e) {
      print('❌ Error leaving live: $e');
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _socketSubscription?.cancel();
    _messageController.dispose();
    _messageScrollController.dispose();
    _leaveLive();
    _engine.leaveChannel();
    _engine.release();
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildVideoGrid()),
                _buildChatSection(),
                _buildBottomControls(),
              ],
            ),
          ],
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
            ),
            const SizedBox(height: 24),
            Text(
              widget.isHost
                  ? 'Starting video party...'
                  : 'Joining video party...',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Icon(Icons.videocam, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'VIDEO PARTY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${widget.liveStream.viewersCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    final numberOfSeats = widget.liveStream.numberOfChairs;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: numberOfSeats <= 4 ? 2 : 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: numberOfSeats,
      itemBuilder: (context, index) {
        final seat = _seats.firstWhere(
          (s) => s.seatIndex == index,
          orElse:
              () => AudioChatUserModel(
                id: '',
                liveStreamId: widget.liveStream.id,
                seatIndex: index,
                canTalk: false,
                enabledVideo: false,
                enabledAudio: false,
                leftRoom: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
        );

        return _buildVideoCard(seat, index);
      },
    );
  }

  Widget _buildVideoCard(AudioChatUserModel seat, int index) {
    final isOccupied = seat.joinedUserId != null && !seat.leftRoom;
    final isMe = seat.seatIndex == _mySeatIndex;

    return GestureDetector(
      onTap: () {
        if (!isOccupied && _mySeatIndex == null) {
          _joinSeat(index);
        } else if (isMe) {
          _leaveSeat();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isMe
                    ? const Color(0xFF4ECDC4)
                    : isOccupied
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Video view
            if (isOccupied && seat.enabledVideo)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine,
                    canvas: VideoCanvas(uid: seat.joinedUserUid),
                    connection: RtcConnection(
                      channelId: widget.liveStream.streamingChannel,
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor:
                          isOccupied
                              ? const Color(0xFF667eea)
                              : const Color(0xFF3A3A3A),
                      backgroundImage:
                          isOccupied && seat.joinedUser?.profileImageUrl != null
                              ? CachedNetworkImageProvider(
                                seat.joinedUser!.profileImageUrl!,
                              )
                              : null,
                      child:
                          !isOccupied
                              ? const Icon(Icons.person_add, color: Colors.grey)
                              : seat.joinedUser?.profileImageUrl == null
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isOccupied
                          ? seat.joinedUser?.displayName ?? 'User'
                          : 'Empty',
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

            // Mute indicator
            if (isOccupied && !seat.enabledAudio)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // Seat number
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatSection() {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _messageScrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${message.author?.displayName ?? 'User'}: ',
                          style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                          text: message.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Say something...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send, color: Color(0xFF667eea)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_mySeatIndex != null) ...[
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? 'Unmute' : 'Mute',
              onTap: _toggleMute,
              color: _isMuted ? Colors.red : const Color(0xFF667eea),
            ),
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              label: _isVideoEnabled ? 'Video On' : 'Video Off',
              onTap: _toggleVideo,
              color: _isVideoEnabled ? const Color(0xFF667eea) : Colors.grey,
            ),
            _buildControlButton(
              icon: Icons.cameraswitch,
              label: 'Switch',
              onTap: _switchCamera,
              color: const Color(0xFF667eea),
            ),
            _buildControlButton(
              icon: Icons.exit_to_app,
              label: 'Leave',
              onTap: _leaveSeat,
              color: Colors.red,
            ),
          ] else ...[
            _buildControlButton(
              icon: Icons.chair,
              label: 'Join Seat',
              onTap: () {
                final emptySeat = _seats.firstWhere(
                  (s) => s.joinedUserId == null || s.leftRoom,
                  orElse: () => _seats.first,
                );
                _joinSeat(emptySeat.seatIndex);
              },
              color: const Color(0xFF667eea),
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
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
