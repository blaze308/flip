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
import '../../models/user_model.dart';
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

  bool _isJoining = true;
  bool _isMuted = true;
  bool _liveStreamCreated = false; // Track if live stream was created in backend
  String? _createdLiveStreamId; // Store the created live stream ID
  int? _localUid;
  int? _mySeatIndex;
  Map<int, bool> _remoteSpeaking = {}; // uid -> isSpeaking
  Map<int, AnimationController> _waveAnimations = {};
  bool _isSwitchingSeat = false; // Prevent rapid seat switching
  bool _isDisposed = false; // Guard async callbacks after dispose

  Timer? _heartbeatTimer;
  StreamSubscription? _socketSubscription;

  String get _currentLiveStreamId => _createdLiveStreamId ?? widget.liveStream.id;

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
            if (_isDisposed) return;
            if (mounted) {
              setState(() {
                _localUid = connection.localUid;
                _isJoining = false;
              });
            }

            // Create live stream in backend AFTER successful channel join (only for hosts)
            if (widget.isHost && !_liveStreamCreated) {
              _createLiveStream().then((_) async {
                await _loadSeats();
                await _joinHostSeat();
              });
            }
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
      await _engine.setDefaultAudioRouteToSpeakerphone(true);
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
    if (_currentLiveStreamId.isEmpty) {
      print('⚠️ Cannot load seats: live stream ID is empty');
      return;
    }
    try {
      final seats = await LiveStreamingService.getPartySeats(
        _currentLiveStreamId,
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

      if (_currentLiveStreamId.isEmpty) {
        print('⚠️ Cannot join as viewer: live stream ID is empty');
        return;
      }

      await LiveStreamingService.joinLiveStream(
        liveStreamId: _currentLiveStreamId,
        userUid: int.parse(user.id.hashCode.toString().substring(0, 8)),
      );

      SocketService.instance.socket?.emit('live:join', {
        'liveStreamId': _currentLiveStreamId,
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
      if (_isDisposed) return;
      if (data['liveStreamId'] == _currentLiveStreamId) {
        _onLiveEnded();
      }
    });

    socket.on('live:seat:update', (data) {
      if (_isDisposed) return;
      _onSeatUpdate(data);
    });

    socket.on('live:host:action', (data) {
      if (_isDisposed) return;
      _onHostAction(data);
    });

    socket.on('live:message', (data) {
      if (_isDisposed) return;
      _onNewMessage(data);
    });
  }

  void _onUserJoined(int uid) {
    if (_isDisposed) return;
    try {
      _engine.muteRemoteAudioStream(uid: uid, mute: false);
    } catch (e) {
      print('⚠️ Error unmuting remote audio: $e');
    }
    if (mounted) {
      setState(() {
        _remoteSpeaking[uid] = false;
      });
    }
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
        case 'removed':
          ToasterService.showError(
            context,
            'You have been removed from the audio party',
          );
          _leaveLive(showConfirmation: false);
          break;
      }
    }
  }

  void _onNewMessage(Map<String, dynamic> data) {
    if (_isDisposed) return;
    try {
      final message = LiveMessageModel.fromJson(data['message']);
      if (mounted) {
        setState(() {
          _messages.add(message);
        });
      }

      // Auto-scroll to latest
      if (_messageScrollController.hasClients) {
        _messageScrollController.animateTo(
          _messageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('❌ Error handling new message: $e');
    }
  }

  void _onLiveEnded() {
    if (_isDisposed) return;
    if (mounted) {
      ToasterService.showInfo(context, 'Audio party has ended');
      Navigator.pop(context);
    }
  }

  /// Host-only: toggle another user's audio (mute/unmute) locally and notify backend
  Future<void> _toggleUserAudio(AudioChatUserModel seat) async {
    if (!widget.isHost) return;
    if (seat.joinedUserUid == null) return;

    final newMutedState = !seat.enabledAudio; // toggle

    // Authoritative backend call
    if (seat.joinedUserId != null) {
      try {
        if (newMutedState) {
          await LiveStreamingService.mutePartyUser(
            liveStreamId: _currentLiveStreamId,
            targetUserId: seat.joinedUserId!,
            seatIndex: seat.seatIndex,
          );
        } else {
          await LiveStreamingService.unmutePartyUser(
            liveStreamId: _currentLiveStreamId,
            targetUserId: seat.joinedUserId!,
            seatIndex: seat.seatIndex,
          );
        }
      } catch (e) {
        print('❌ Error calling host mute API: $e');
        ToasterService.showError(
          context,
          'Failed to ${newMutedState ? "mute" : "unmute"} user',
        );
        return;
      }
    }

    // Best-effort local enforcement: mute/unmute remote audio
    try {
      await _engine.muteRemoteAudioStream(
        uid: seat.joinedUserUid!,
        mute: newMutedState,
      );
    } catch (e) {
      print('⚠️ Error toggling remote audio locally: $e');
    }

    ToasterService.showInfo(
      context,
      newMutedState ? 'User muted' : 'User unmuted',
    );

    await _loadSeats();
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isDisposed) return;
      _loadSeats();
    });
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine.muteLocalAudioStream(_isMuted);
  }

  Future<void> _joinSeat(int seatIndex) async {
    if (_isSwitchingSeat) return;

    if (_currentLiveStreamId.isEmpty) {
      ToasterService.showError(context, 'Live stream not ready');
      return;
    }

    // Hosts are locked to seat 0 in TikTok-style party mode
    if (widget.isHost && seatIndex != 0) {
      ToasterService.showInfo(
        context,
        'Hosts cannot change seats. You are always in seat 0.',
      );
      return;
    }

    // Prevent switching to same seat
    if (_mySeatIndex == seatIndex) {
      print('⚠️ Already in this seat');
      return;
    }

    final user = TokenAuthService.currentUser;
    if (user == null) return;

    final prevCanTalk =
        _mySeatIndex != null ? _seats[_mySeatIndex!].canTalk : null;

    setState(() => _isSwitchingSeat = true);

    try {
      // If already in a seat, leave it first (non-host only)
      if (_mySeatIndex != null && !widget.isHost) {
        try {
          await LiveStreamingService.leavePartySeat(
            liveStreamId: _currentLiveStreamId,
            seatIndex: _mySeatIndex!,
          );
          print('✅ Left seat $_mySeatIndex before switching');
        } catch (e) {
          print('⚠️ Error leaving old seat: $e');
        }
      }

      await LiveStreamingService.joinPartySeat(
        liveStreamId: _currentLiveStreamId,
        seatIndex: seatIndex,
        userUid: _localUid ?? 0,
        canTalk: widget.isHost ? true : prevCanTalk,
      );

      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      if (mounted) {
        setState(() {
          _mySeatIndex = seatIndex;
        });
      }

      ToasterService.showSuccess(context, 'Joined seat ${seatIndex + 1}');
      _loadSeats(); // non-blocking refresh
    } catch (e) {
      print('❌ Error joining seat: $e');
      ToasterService.showError(context, 'Failed to join seat');
    } finally {
      if (mounted) {
        setState(() => _isSwitchingSeat = false);
      }
    }
  }

  Future<void> _joinHostSeat() async {
    if (!widget.isHost) return;
    if (_localUid == null) return;
    if (_currentLiveStreamId.isEmpty) {
      print('⚠️ Cannot join host seat: live stream ID is empty');
      return;
    }

    try {
      await LiveStreamingService.joinPartySeat(
        liveStreamId: _currentLiveStreamId,
        seatIndex: 0,
        userUid: _localUid!,
      );

      if (mounted && !_isDisposed) {
        setState(() => _mySeatIndex = 0);
      }

      // Notify via socket (best-effort)
      SocketService.instance.socket?.emit('live:seat:joined', {
        'liveStreamId': _currentLiveStreamId,
        'seatIndex': 0,
        'uid': _localUid,
      });

      print('✅ Host joined seat 0');
    } catch (e) {
      print('❌ Error joining host seat: $e');
    }
  }

  Future<void> _leaveSeat() async {
    // Hosts cannot leave their seat; they must end the live
    if (widget.isHost) {
      ToasterService.showInfo(
        context,
        'Hosts cannot leave their seat. End the live stream to leave.',
      );
      return;
    }

    if (_mySeatIndex == null) return;

    if (_currentLiveStreamId.isEmpty) {
      print('⚠️ Cannot leave seat: live stream ID is empty');
      return;
    }

    try {
      await LiveStreamingService.leavePartySeat(
        liveStreamId: _currentLiveStreamId,
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

    final liveStreamId = _currentLiveStreamId;
    if (liveStreamId.isEmpty) {
      ToasterService.showError(context, 'Live stream not ready');
      return;
    }

    try {
      // Clear input immediately for better UX
      _messageController.clear();

      await LiveStreamingService.sendMessage(
        liveStreamId: liveStreamId,
        message: text,
        messageType: 'COMMENT',
      );

      // Add message locally with author info
      final user = TokenAuthService.currentUser;
      if (user != null && mounted && !_isDisposed) {
        final author = UserModel(
          id: user.id,
          username: user.displayName ?? 'user',
          displayName: user.displayName ?? 'User',
          email: user.email,
          phoneNumber: user.phoneNumber,
          profileImageUrl: user.photoURL,
          accountBadge: '',
          postsCount: 0,
          followersCount: 0,
          followingCount: 0,
          likesCount: 0,
          isFollowing: false,
          isFollower: false,
        );

        final message = LiveMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          authorId: user.id,
          author: author,
          liveStreamId: liveStreamId,
          message: text,
          messageType: 'COMMENT',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        _onNewMessage({'message': message.toJson()});
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      // Only show error if text still present (send failed before clear)
      if (mounted && _messageController.text == text) {
        ToasterService.showError(context, 'Failed to send message');
      }
    }
  }

  /// Create live stream in backend AFTER successful Agora initialization
  Future<void> _createLiveStream() async {
    if (!widget.isHost || _liveStreamCreated) return;

    try {
      final user = TokenAuthService.currentUser;
      if (user == null) return;

      final liveStream = await LiveStreamingService.createLiveStream(
        liveType: 'audio',
        streamingChannel: widget.liveStream.streamingChannel,
        authorUid: widget.liveStream.authorUid,
        partyType: widget.liveStream.partyType,
        numberOfChairs: widget.liveStream.numberOfChairs,
      );

      setState(() {
        _liveStreamCreated = true;
        _createdLiveStreamId = liveStream.id;
      });

      print('✅ Live stream created in backend: ${liveStream.id}');
    } catch (e) {
      print('❌ Error creating live stream: $e');
      if (mounted) {
        ToasterService.showError(
          context,
          'Failed to register live stream',
        );
        Navigator.pop(context);
      }
    }
  }

  /// End live stream in backend
  Future<void> _endLiveStream() async {
    if (!_liveStreamCreated || _createdLiveStreamId == null) return;

    try {
      await LiveStreamingService.endLiveStream(_createdLiveStreamId!);
      print('✅ Live stream ended: $_createdLiveStreamId');
    } catch (e) {
      print('❌ Error ending live stream: $e');
    }
  }

  Future<void> _leaveLive({
    bool showConfirmation = true,
    bool navigateBack = true,
  }) async {
    try {
      // Viewers: leave seat first if occupied
      if (!widget.isHost && _mySeatIndex != null) {
        await _leaveSeat();
      }

      bool shouldLeave = true;

      if (showConfirmation && mounted) {
        final result = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A1A),
                title: const Text(
                  'Leave Audio Party?',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  widget.isHost
                      ? 'End the audio party for everyone?'
                      : 'Are you sure you want to leave the audio party?',
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text(
                      'Leave',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        );
        shouldLeave = result == true;
      }

      if (!shouldLeave) return;

      // Hosts end live stream
      if (widget.isHost && _liveStreamCreated) {
        await _endLiveStream();
      } else if (!widget.isHost && _currentLiveStreamId.isNotEmpty) {
        // Viewers leave live stream
        final user = TokenAuthService.currentUser;
        final uid = _localUid ?? int.tryParse(user?.id.hashCode.toString().substring(0, 8) ?? '0') ?? 0;

        await LiveStreamingService.leaveLiveStream(
          liveStreamId: _currentLiveStreamId,
          userUid: uid,
        );

        SocketService.instance.socket?.emit('live:leave', {
          'liveStreamId': _currentLiveStreamId,
          'uid': uid,
        });

        print('✅ Left live');
      }

      if (navigateBack && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error leaving live: $e');
    }
  }

  /// Silent cleanup during dispose (no dialogs or navigation)
  Future<void> _cleanupOnDispose() async {
    try {
      // Viewers: leave seat silently
      if (!widget.isHost &&
          _mySeatIndex != null &&
          _currentLiveStreamId.isNotEmpty) {
        await LiveStreamingService.leavePartySeat(
          liveStreamId: _currentLiveStreamId,
          seatIndex: _mySeatIndex!,
        );
      }

      // Hosts already end live in dispose
      if (widget.isHost) return;

      if (_currentLiveStreamId.isNotEmpty) {
        final uid = _localUid ?? 0;
        await LiveStreamingService.leaveLiveStream(
          liveStreamId: _currentLiveStreamId,
          userUid: uid,
        );

        SocketService.instance.socket?.emit('live:leave', {
          'liveStreamId': _currentLiveStreamId,
          'uid': uid,
        });
      }
    } catch (e) {
      print('⚠️ Error during dispose cleanup: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _heartbeatTimer?.cancel();
    _socketSubscription?.cancel();
    _messageController.dispose();
    _messageScrollController.dispose();
    for (var controller in _waveAnimations.values) {
      controller.dispose();
    }
    
    // IMPORTANT: For hosts, end live stream FIRST before any navigation
    // This ensures the live stream is marked as ended in backend
    if (widget.isHost && _liveStreamCreated) {
      _endLiveStream();
    }
    
    // Leave live stream (for viewers only, silent)
    _cleanupOnDispose();
    
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

    return WillPopScope(
      onWillPop: () async {
        if (!widget.isHost && _mySeatIndex != null) {
          await _leaveSeat();
        }

        if (mounted) {
          final shouldLeave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'Leave Audio Party?',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                widget.isHost
                    ? 'End the audio party for everyone?'
                    : 'Are you sure you want to leave the audio party?',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text(
                    'Leave',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );

          if (shouldLeave == true) {
            await _leaveLive(showConfirmation: false, navigateBack: true);
          }
        }

        return false; // We handle navigation ourselves
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/audio_room_background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildAudioSeatsGrid()),
                _buildChatSection(),
                _buildBottomControls(),
              ],
            ),
          ),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
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
              color: Colors.white.withOpacity(0.1),
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

  Widget _buildAudioSeatsGrid() {
    final numberOfSeats = widget.liveStream.numberOfChairs;

    final showTwoColumn = numberOfSeats <= 4;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: showTwoColumn ? 2 : 3,
        childAspectRatio: showTwoColumn ? 1.0 : 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: numberOfSeats,
      itemBuilder: (context, index) {
        final seat = _seats.firstWhere(
          (s) => s.seatIndex == index,
          orElse: () => AudioChatUserModel(
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
        if (_isSwitchingSeat) return;

        if (!isOccupied) {
          // Hosts can only ever sit in seat 0
          if (widget.isHost && index != 0) {
            ToasterService.showInfo(
              context,
              'Hosts cannot change seats. You are always in seat 0.',
            );
            return;
          }
          _joinSeat(index);
        } else if (isMe && !widget.isHost) {
          _leaveSeat();
        }
      },
      onLongPress: () {
        // Host long-press to toggle user audio (mute/unmute)
        if (widget.isHost && isOccupied && !isMe) {
          _toggleUserAudio(seat);
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
            // Diamonds badge
            if (isOccupied && seat.joinedUser != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.diamond, color: Colors.pink, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${seat.joinedUser?.diamonds ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
        color: Colors.black.withOpacity(0.3),
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
                    fillColor: Colors.white.withOpacity(0.1),
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
        color: Colors.black.withOpacity(0.4),
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
              onTap: () {
                if (widget.isHost) {
                  _leaveLive(); // host ending live
                } else {
                  _leaveSeat();
                }
              },
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
