import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../models/live_stream_model.dart';
import '../../models/audio_chat_user_model.dart';
import '../../models/live_message_model.dart';
import '../../services/live_streaming_service.dart';
import '../../services/token_auth_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/custom_toaster.dart';

/// Agora Audio Party Screen
/// Multi-host AUDIO-ONLY room with seats
/// Features: Voice chat, seat management, host controls, real-time chat
/// STRICTLY AUDIO - No video, only voice
class AgoraAudioPartyScreen extends StatefulWidget {
  final LiveStreamModel liveStream;
  final bool isHost;

  const AgoraAudioPartyScreen({
    super.key,
    required this.liveStream,
    this.isHost = false,
  });

  @override
  State<AgoraAudioPartyScreen> createState() => _AgoraAudioPartyScreenState();
}

class _AgoraAudioPartyScreenState extends State<AgoraAudioPartyScreen>
    with TickerProviderStateMixin {
  late RtcEngine _engine;
  List<AudioChatUserModel> _seats = [];
  List<LiveMessageModel> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  bool _isInitialized = false;
  bool _isJoining = true;
  bool _isMuted = true;
  int? _localUid;
  int? _mySeatIndex;
  Map<int, bool> _remoteSpeaking = {}; // uid -> isSpeaking
  Map<int, AnimationController> _waveAnimations = {};

  Timer? _heartbeatTimer;
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    try {
      // Request microphone permission only - NO CAMERA for audio party
      final micStatus = await Permission.microphone.request();

      if (micStatus.isDenied) {
        if (mounted) {
          ToasterService.showError(
            context,
            'Microphone permission required for audio party',
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
            print('✅ Joined AUDIO party: ${connection.channelId}');
            setState(() {
              _localUid = connection.localUid;
              _isJoining = false;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            print('👤 User joined AUDIO party: $remoteUid');
            _onUserJoined(remoteUid);
          },
          onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            print('👋 User left AUDIO party: $remoteUid');
            _onUserLeft(remoteUid);
          },
          onAudioVolumeIndication: (
            RtcConnection connection,
            List<AudioVolumeInfo> speakers,
            int speakerNumber,
            int totalVolume,
          ) {
            for (var speaker in speakers) {
              if (speaker.volume! > 10) {
                setState(() {
                  _remoteSpeaking[speaker.uid!] = true;
                });
                _startWaveAnimation(speaker.uid!);
              } else {
                setState(() {
                  _remoteSpeaking[speaker.uid!] = false;
                });
              }
            }
          },
          onError: (ErrorCodeType err, String msg) {
            print('❌ Agora error: $err - $msg');
          },
        ),
      );

      // DISABLE VIDEO - This is an AUDIO-ONLY party!
      await _engine.disableVideo();
      await _engine.enableAudio();
      await _engine.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );

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
      print('❌ Error initializing AUDIO party: $e');
      if (mounted) {
        ToasterService.showError(context, 'Failed to initialize audio party');
        Navigator.pop(context);
      }
    }
  }

  void _startWaveAnimation(int uid) {
    if (!_waveAnimations.containsKey(uid)) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      _waveAnimations[uid] = controller;
    }

    _waveAnimations[uid]?.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !(_remoteSpeaking[uid] ?? false)) {
        _waveAnimations[uid]?.reverse();
      }
    });
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

      print('✅ Joined AUDIO party as viewer');
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
      _remoteSpeaking[uid] = false;
    });
  }

  void _onUserLeft(int uid) {
    setState(() {
      _remoteSpeaking.remove(uid);
      _waveAnimations[uid]?.dispose();
      _waveAnimations.remove(uid);
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
        case 'removed':
          ToasterService.showError(
            context,
            'You have been removed from the audio party',
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
      ToasterService.showInfo(context, 'Audio party has ended');
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

      setState(() {
        _mySeatIndex = seatIndex;
      });

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
    for (var controller in _waveAnimations.values) {
      controller.dispose();
    }
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
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildAudioSeatsGrid()),
            _buildChatSection(),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFf093fb)),
            ),
            const SizedBox(height: 24),
            Text(
              widget.isHost
                  ? 'Starting audio party...'
                  : 'Joining audio party...',
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
      decoration: const BoxDecoration(color: Color(0xFF2A2A2A)),
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
              color: const Color(0xFFf093fb),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Icon(Icons.mic, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'AUDIO PARTY',
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

  Widget _buildAudioSeatsGrid() {
    final numberOfSeats = widget.liveStream.numberOfChairs;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: numberOfSeats <= 4 ? 2 : 3,
        childAspectRatio: 1.0,
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

        return _buildAudioSeatCard(seat, index);
      },
    );
  }

  Widget _buildAudioSeatCard(AudioChatUserModel seat, int index) {
    final isOccupied = seat.joinedUserId != null && !seat.leftRoom;
    final isMe = seat.seatIndex == _mySeatIndex;
    final isSpeaking = _remoteSpeaking[seat.joinedUserUid] ?? false;

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
                    ? const Color(0xFFf093fb)
                    : isSpeaking
                    ? const Color(0xFFf093fb).withOpacity(0.6)
                    : isOccupied
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
            width: isSpeaking ? 3 : 2,
          ),
          boxShadow:
              isSpeaking
                  ? [
                    BoxShadow(
                      color: const Color(0xFFf093fb).withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                  : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar with wave animation
                  AnimatedBuilder(
                    animation:
                        _waveAnimations[seat.joinedUserUid] ??
                        AlwaysStoppedAnimation(0),
                    builder: (context, child) {
                      final scale =
                          isSpeaking
                              ? 1.0 +
                                  (_waveAnimations[seat.joinedUserUid]?.value ??
                                          0) *
                                      0.1
                              : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              isOccupied
                                  ? const Color(0xFFf093fb)
                                  : const Color(0xFF3A3A3A),
                          backgroundImage:
                              isOccupied &&
                                      seat.joinedUser?.profileImageUrl != null
                                  ? CachedNetworkImageProvider(
                                    seat.joinedUser!.profileImageUrl!,
                                  )
                                  : null,
                          child:
                              !isOccupied
                                  ? const Icon(
                                    Icons.person_add,
                                    color: Colors.grey,
                                    size: 30,
                                  )
                                  : seat.joinedUser?.profileImageUrl == null
                                  ? const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 30,
                                  )
                                  : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isOccupied
                        ? seat.joinedUser?.displayName ?? 'User'
                        : 'Empty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (isSpeaking)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Speaking...',
                        style: TextStyle(
                          color: Color(0xFFf093fb),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
      decoration: const BoxDecoration(color: Color(0xFF2A2A2A)),
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
                            color: Color(0xFFf093fb),
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
                    fillColor: const Color(0xFF1A1A1A),
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
                icon: const Icon(Icons.send, color: Color(0xFFf093fb)),
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
        color: const Color(0xFF2A2A2A),
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
              color: _isMuted ? Colors.red : const Color(0xFFf093fb),
            ),
            _buildControlButton(
              icon: Icons.exit_to_app,
              label: 'Leave Seat',
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
              color: const Color(0xFFf093fb),
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
