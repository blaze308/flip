import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ========== AGORA ENGINE & STATE ==========
  late RtcEngine _engine;
  bool _engineCreated = false;
  bool _engineInitialized = false;
  bool _isInitialized = false;
  bool _isJoining = true;
  bool _liveStreamCreated =
      false; // Track if live stream was created in backend
  String? _createdLiveStreamId; // Store the created live stream ID
  int? _localUid;

  // ========== SEAT MANAGEMENT ==========
  final Map<int, AudioChatUserModel> _seats = {}; // index -> seat data
  final Map<int, int> _remoteUserToSeat = {}; // uid -> seat index
  int? _mySeatIndex;
  bool _isSwitchingSeat = false; // Prevent multiple seat switches

  // Performance optimization
  DateTime? _lastSeatsLoadTime; // Track last seat load
  final Duration _seatsLoadDebounce = const Duration(
    seconds: 5,
  ); // Debounce seat loads
  bool _seatsLoadPending = false; // Prevent duplicate load requests

  // ========== AUDIO/VIDEO CONTROLS ==========
  bool _isMuted =
      false; // Start UNMUTED for better UX (users expect to be heard in party)
  bool _isVideoEnabled = true; // VIDEO party - enable by default
  bool _isVideoDisabledByHost = false;
  bool _wasVideoEnabledBeforePause = true; // Track video state before pause

  // ========== CHAT & MESSAGING ==========
  final List<LiveMessageModel> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  final ScrollController _videoGridScrollController = ScrollController();

  // ========== PLATFORM SPEAKER ==========
  int _platformSpeakerNumber = 0;
  bool _showPlatformTextField = false;
  bool _canSendPlatformMessage = false;
  final TextEditingController _platformTextController = TextEditingController();
  final GlobalKey<FormState> _platformFormKey = GlobalKey<FormState>();

  // Platform message display
  Map<String, dynamic>? _currentPlatformMessage;
  late AnimationController _platformMessageController;
  late Animation<Offset> _platformMessageAnimation;

  // ========== REAL-TIME UPDATES ==========
  Timer? _heartbeatTimer;
  StreamSubscription? _socketSubscription;
  bool _isLiveActive = true;
  bool _isDisposed = false; // Track disposal state to prevent memory leaks

  // ========== UI STATE ==========
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _engine = createAgoraRtcEngine();
    _engineCreated = true;
    WidgetsBinding.instance.addObserver(this);
    _checkPlatformSpeakerNumber();

    // Initialize platform message animation
    _platformMessageController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    _platformMessageAnimation = Tween<Offset>(
      begin: const Offset(3.0, 0.0),
      end: const Offset(-1.0, 0.0),
    ).animate(
      CurvedAnimation(
        parent: _platformMessageController,
        curve: Curves.easeInOut,
      ),
    );

    _initialize();
  }

  /// Check platform speaker number and set canSend flag
  /// Based on old implementation: checkPlatformSpeakerNumber
  void _checkPlatformSpeakerNumber() {
    final user = TokenAuthService.currentUser;
    if (user == null) return;
    if (_currentLiveStreamId.isEmpty) return;

    LiveStreamingService.getPlatformSpeakerQuota(
          liveStreamId: _currentLiveStreamId,
        )
        .then((remaining) {
          if (!mounted || _isDisposed) return;
          setState(() {
            _platformSpeakerNumber = remaining;
            _canSendPlatformMessage = remaining > 0;
          });
        })
        .catchError((e) {
          print('⚠️ Error fetching platform quota: $e');
        });
  }

  /// Send platform message (broadcast to all viewers)
  /// Based on old implementation: sendPlatformMessage
  Future<void> _sendPlatformMessage(String message) async {
    if (!_canSendPlatformMessage || _platformSpeakerNumber <= 0) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Cannot Send Message'),
              content: const Text(
                'You are not allowed to send a platform message at this time.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    if (!(_platformFormKey.currentState?.validate() ?? false)) return;
    if (_currentLiveStreamId.isEmpty) return;

    try {
      final result = await LiveStreamingService.sendPlatformSpeakerMessage(
        liveStreamId: _currentLiveStreamId,
        message: message,
      );

      final remaining =
          (result['remaining'] as num?)?.toInt() ?? _platformSpeakerNumber;
      final payload = result['payload'] as Map<String, dynamic>? ?? {};

      if (mounted) {
        setState(() {
          _platformSpeakerNumber = remaining;
          _canSendPlatformMessage = remaining > 0;
          _showPlatformTextField = false;
          _platformTextController.clear();
        });
      }

      // Show locally immediately
      _onPlatformMessage(payload);

      print('✅ Platform message sent via backend');
    } catch (e) {
      print('❌ Error sending platform message: $e');
      ToasterService.showError(context, 'Failed to send platform message');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized || !mounted) return;

    switch (state) {
      case AppLifecycleState.paused:
        // CRITICAL FIX: Save video state ONLY - don't make any engine calls
        // Making calls during pause can cause conflicts with Agora's internal state
        _wasVideoEnabledBeforePause = _isVideoEnabled;
        break;
      case AppLifecycleState.resumed:
        // CRITICAL FIX: Only restore if video was actually enabled AND not disabled by host
        // Use a small delay to allow Agora engine to fully reinitialize
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted || !_isInitialized || _isVideoDisabledByHost) return;

          // Only call if we actually need to enable (video was on before pause)
          if (_wasVideoEnabledBeforePause && _isVideoEnabled) {
            try {
              _engine.startPreview();
              _engine.muteLocalVideoStream(false);
            } catch (e) {
              print('⚠️ Error restoring video on resume: $e');
            }
          }
        });
        break;
      case AppLifecycleState.inactive:
        // CRITICAL FIX: Don't do anything on inactive - it's just a transition state
        // This prevents random camera disable issues
        break;
      case AppLifecycleState.hidden:
        // Don't do anything - video stays on
        break;
      case AppLifecycleState.detached:
        // Don't do anything - dispose() will handle cleanup
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

      // Ensure engine exists (defensive)
      if (!_engineCreated) {
        _engine = createAgoraRtcEngine();
        _engineCreated = true;
      }

      // Initialize Agora engine
      await _engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      _engineInitialized = true;

      // Register event handler
      _setupEventHandler();

      // Enable audio and video
      await _engine.enableVideo();
      await _engine.enableLocalVideo(true); // ensure camera is active
      await _engine.enableAudio();

      // CRITICAL: Initialize audio mute state to match our flag
      // This ensures engine state is consistent with UI state
      await _engine.muteLocalAudioStream(_isMuted);
      await _engine.muteLocalVideoStream(!_isVideoEnabled);

      // CRITICAL: Set audio route to speakerphone for better audio experience
      await _engine.setDefaultAudioRouteToSpeakerphone(true);

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
        role:
            widget.isHost
                ? ClientRoleType.clientRoleBroadcaster
                : ClientRoleType
                    .clientRoleBroadcaster, // Everyone broadcasts in party
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

      // Don't load seats yet - wait for live stream to be created after channel join
      // Seats will be loaded in onJoinChannelSuccess after _createLiveStream()

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
      _engineInitialized = false;
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

          // Create live stream in backend AFTER successful channel join (only for hosts)
          if (widget.isHost && !_liveStreamCreated) {
            _createLiveStream().then((_) async {
              // After live stream is created, load seats first
              await _loadSeats();
              // CRITICAL: Hosts are ALWAYS assigned seat 0 automatically (like TikTok party mode)
              // This ensures hosts are always in a seat and can participate immediately
              await _joinHostSeat();
            });
          } else if (!widget.isHost) {
            // For viewers, join as viewer (they use existing live stream ID)
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
                  enabledVideo:
                      state == RemoteVideoState.remoteVideoStateDecoding,
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
                  enabledAudio:
                      state == RemoteAudioState.remoteAudioStateDecoding,
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
            ToasterService.showError(
              context,
              'Connection failed, attempting to reconnect...',
            );
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
      if (_isDisposed) return;
      print('🪑 Seat updated: $data');
      // PERFORMANCE FIX: Reset debounce to force immediate load on important updates
      _lastSeatsLoadTime = null;
      _seatsLoadPending = false;
      _loadSeats();
    });

    // Listen for host actions (mute, remove, etc)
    socket.on('live:host:action', (data) {
      if (_isDisposed) return;
      print('🎬 Host action: $data');
      _onHostAction(data);
    });

    // Listen for new messages
    socket.on('live:message:new', (data) {
      if (_isDisposed) return;
      print('💬 New message: $data');
      _onNewMessage(data);
    });

    // Listen for platform messages
    socket.on('live:platform:message', (data) {
      if (_isDisposed) return;
      print('📢 Platform message: $data');
      _onPlatformMessage(data);
    });

    // Listen for live ended
    socket.on('live:ended', (data) {
      if (_isDisposed) return;
      print('🔴 Live ended');
      _onLiveEnded();
    });

    // Listen for user removed
    socket.on('live:user:removed', (data) {
      if (_isDisposed) return;
      if (data['userId'] == TokenAuthService.currentUser?.id) {
        print('❌ You were removed from the live');
        ToasterService.showError(context, 'You were removed from the party');
        _leaveLive(showConfirmation: false);
      }
    });
  }

  /// Handle incoming platform message
  void _onPlatformMessage(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        _currentPlatformMessage = data;
      });

      // Start animation
      _platformMessageController.forward().then((_) {
        _platformMessageController.reset();
      });
    }
  }

  /// Create live stream in backend AFTER successful Agora initialization
  Future<void> _createLiveStream() async {
    if (!widget.isHost || _liveStreamCreated) return;

    try {
      final user = TokenAuthService.currentUser;
      if (user == null) return;

      final liveStream = await LiveStreamingService.createLiveStream(
        liveType: 'party',
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
        ToasterService.showError(context, 'Failed to register live stream');
        Navigator.pop(context);
      }
    }
  }

  /// End live stream in backend
  Future<void> _endLiveStream() async {
    final liveId = _currentLiveStreamId;
    if (liveId.isEmpty) {
      print('⚠️ Cannot end live: live stream ID is empty');
      return;
    }

    try {
      await LiveStreamingService.endLiveStream(liveId);
      print('✅ Live stream ended: $liveId');
    } catch (e) {
      print('❌ Error ending live stream: $e');
    }
  }

  /// Get the current live stream ID (created or from widget)
  String get _currentLiveStreamId =>
      _createdLiveStreamId ?? widget.liveStream.id;

  Future<void> _loadSeats() async {
    // Don't load seats if live stream ID is empty
    if (_currentLiveStreamId.isEmpty) {
      print('⚠️ Cannot load seats: live stream ID is empty');
      return;
    }

    // PERFORMANCE FIX: Debounce seat loads - avoid hammering backend
    // Only load if:
    // 1. No load is currently pending, AND
    // 2. Either first time OR enough time has passed since last load
    final now = DateTime.now();
    if (_seatsLoadPending) {
      return; // Already loading, skip duplicate request
    }

    if (_lastSeatsLoadTime != null &&
        now.difference(_lastSeatsLoadTime!).inSeconds <
            _seatsLoadDebounce.inSeconds) {
      return; // Too soon, skip
    }

    try {
      _seatsLoadPending = true;
      _lastSeatsLoadTime = now;

      final seats = await LiveStreamingService.getPartySeats(
        _currentLiveStreamId,
      );

      if (!mounted || _isDisposed) return;

      // PERFORMANCE FIX: Use single setState call instead of multiple
      setState(() {
        // Only rebuild if seats actually changed
        bool seatsChanged = false;

        // Check if any seat data changed
        for (final seat in seats) {
          final oldSeat = _seats[seat.seatIndex];
          if (oldSeat == null || oldSeat != seat) {
            seatsChanged = true;
            break;
          }
        }

        if (seatsChanged) {
          // Clear old remote user mappings for users who left
          final occupiedUserUids =
              seats
                  .where((s) => s.joinedUserUid != null && !s.leftRoom)
                  .map((s) => s.joinedUserUid!)
                  .toSet();

          _remoteUserToSeat.removeWhere(
            (uid, _) => !occupiedUserUids.contains(uid),
          );

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
        }
      });

      print('✅ Loaded ${seats.length} seats');
    } catch (e) {
      if (!_isDisposed) {
        print('❌ Error loading seats: $e');
      }
    } finally {
      _seatsLoadPending = false;
    }
  }

  void _startHeartbeat() {
    // PERFORMANCE FIX: Increase heartbeat interval from 20s to 30s
    // Reduces backend load while still keeping seat data reasonably fresh
    // GHOST LIVE FIX: Host sends heartbeat to backend every 30s to prevent ghost lives
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isLiveActive || !mounted) return;

      try {
        // Host sends heartbeat to keep party alive
        if (widget.isHost && _currentLiveStreamId.isNotEmpty) {
          final heartbeatResult = await LiveStreamingService.sendHeartbeat(
            _currentLiveStreamId,
          );

          if (heartbeatResult['success'] == true) {
            print('✅ Heartbeat sent successfully');
            // Update local ghost status
            if (heartbeatResult['isGhost'] == true) {
              print('⚠️ Live marked as ghost! Possible connection issues.');
            }
          }
        }

        // Load seats for both host and guests
        await _loadSeats();
      } catch (e) {
        print('⚠️ Heartbeat error: $e');
      }
    });
  }

  Future<void> _joinHostSeat() async {
    if (_localUid == null) return;
    if (_currentLiveStreamId.isEmpty) {
      print('⚠️ Cannot join host seat: live stream ID is empty');
      return;
    }

    try {
      await LiveStreamingService.joinPartySeat(
        liveStreamId: _currentLiveStreamId,
        seatIndex: 0, // Host always takes seat 0
        userUid: _localUid!,
        canTalk: true,
      );

      if (mounted) {
        setState(() => _mySeatIndex = 0);
      }

      // Notify via WebSocket
      final socket = SocketService.instance.socket;
      if (socket != null) {
        socket.emit('live:seat:joined', {
          'liveStreamId': _currentLiveStreamId,
          'seatIndex': 0,
          'uid': _localUid,
        });
      }

      print('✅ Host joined seat 0');
    } catch (e) {
      print('❌ Error joining host seat: $e');
    }
  }

  Future<void> _joinAsViewer() async {
    try {
      final user = TokenAuthService.currentUser;
      if (user == null) return;

      // For viewers, use the existing live stream ID from widget
      if (widget.liveStream.id.isEmpty) {
        print('⚠️ Cannot join as viewer: live stream ID is empty');
        return;
      }

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
    if (_isDisposed) return; // Guard against disposed widget

    print('🔍 Remote user joined, searching seat for UID: $uid');

    try {
      // CRITICAL: Subscribe to remote audio/video streams so we can hear/see them
      // Note: autoSubscribeAudio/Video in ChannelMediaOptions should handle this,
      // but we explicitly unmute to ensure audio works
      _engine.muteRemoteAudioStream(uid: uid, mute: false);
      _engine.muteRemoteVideoStream(uid: uid, mute: false);

      if (mounted) {
        setState(() {
          // Remote user will be mapped when seat data is loaded
        });
      }
    } catch (e) {
      if (!_isDisposed) {
        print('⚠️ Error in _onRemoteUserJoined: $e');
      }
    }
  }

  void _onRemoteUserLeft(int uid) {
    if (_isDisposed) return; // Guard against disposed widget

    try {
      final seatIndex = _remoteUserToSeat[uid];

      if (mounted) {
        setState(() {
          _remoteUserToSeat.remove(uid);
          if (seatIndex != null) {
            print('✅ Removed UID $uid from seat $seatIndex');
          }
        });
      }
    } catch (e) {
      if (!_isDisposed) {
        print('⚠️ Error in _onRemoteUserLeft: $e');
      }
    }
  }

  void _onHostAction(Map<String, dynamic> data) {
    if (_isDisposed) return; // Guard against disposed widget

    try {
      final action = data['action'];
      final targetUserId = data['targetUserId'];
      final user = TokenAuthService.currentUser;

      if (targetUserId != user?.id) return;

      if (!mounted) return; // Safety check before setState

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
          ToasterService.showInfo(
            context,
            'Your video has been disabled by host',
          );
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
          _leaveLive(showConfirmation: false);
          break;

        default:
          print('⚠️ Unknown host action: $action');
      }
    } catch (e) {
      if (!_isDisposed) {
        print('❌ Error in _onHostAction: $e');
      }
    }
  }

  void _onNewMessage(Map<String, dynamic> data) {
    if (_isDisposed) return;

    try {
      final message = LiveMessageModel.fromJson(data);
      if (mounted) {
        setState(() {
          _messages.add(message);
        });

        // Auto-scroll to latest message with safety check
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_isDisposed && _messageScrollController.hasClients) {
            try {
              _messageScrollController.animateTo(
                _messageScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            } catch (e) {
              print('⚠️ Error auto-scrolling chat: $e');
            }
          }
        });
      }
    } catch (e) {
      print('❌ Error parsing message: $e');
    }
  }

  void _onLiveEnded() {
    if (_isDisposed) return; // Guard against disposed widget

    if (mounted) {
      try {
        ToasterService.showInfo(context, 'Video party has ended');
        Navigator.pop(context);
      } catch (e) {
        print('⚠️ Error showing end stream message: $e');
      }
    }
  }

  // ========== CONTROL METHODS ==========

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine.muteLocalAudioStream(_isMuted);

    // Notify via WebSocket
    if (_currentLiveStreamId.isNotEmpty) {
      SocketService.instance.socket?.emit('live:audio:toggled', {
        'liveStreamId': _currentLiveStreamId,
        'muted': _isMuted,
      });
    }

    print(_isMuted ? '🔇 Muted' : '🔊 Unmuted');
  }

  /// Toggle video on/off - updates backend model and engine
  /// Based on old implementation: enableVideo/disableVideo
  Future<void> _toggleVideo() async {
    if (_isVideoDisabledByHost) {
      ToasterService.showInfo(context, 'Host has disabled your video');
      return;
    }

    if (_mySeatIndex == null) {
      ToasterService.showInfo(context, 'Please join a seat first');
      return;
    }

    final newVideoState = !_isVideoEnabled;

    try {
      // Update engine state synchronously without awaiting each call
      // This prevents conflicts and race conditions
      if (newVideoState) {
        // Enable video: do these in sequence, not parallel
        _engine.enableVideo();
        await Future.delayed(const Duration(milliseconds: 100));
        _engine.startPreview();
        await Future.delayed(const Duration(milliseconds: 100));
        _engine.muteLocalVideoStream(false);
      } else {
        // Disable video: mute first, then disable
        _engine.muteLocalVideoStream(true);
        await Future.delayed(const Duration(milliseconds: 100));
        _engine.disableVideo();
      }

      // Update UI state AFTER engine calls complete
      if (mounted) {
        setState(() => _isVideoEnabled = newVideoState);
      }

      // Notify via WebSocket (async, non-blocking)
      if (_currentLiveStreamId.isNotEmpty) {
        SocketService.instance.socket?.emit('live:video:toggled', {
          'liveStreamId': _currentLiveStreamId,
          'seatIndex': _mySeatIndex,
          'enabled': newVideoState,
        });
      }

      print(newVideoState ? '📹 Video enabled' : '📹 Video disabled');
    } catch (e) {
      print('❌ Error toggling video: $e');
      ToasterService.showError(context, 'Failed to toggle video');
    }
  }

  /// Switch camera (front/back)
  /// Based on old implementation: _onSwitchCamera
  Future<void> _switchCamera() async {
    try {
      await _engine.switchCamera();
      print('✅ Camera switched');
    } catch (e) {
      print('❌ Error switching camera: $e');
      ToasterService.showError(context, 'Failed to switch camera');
    }
  }

  /// Join a seat - handles both new joins and seat switching
  /// Based on old implementation: checkCoHostPresenceBeforeAdd
  Future<void> _joinSeat(int seatIndex) async {
    // Prevent multiple simultaneous seat switches
    if (_isSwitchingSeat) {
      print('⚠️ Seat switch already in progress');
      return;
    }

    if (_currentLiveStreamId.isEmpty) {
      ToasterService.showError(context, 'Live stream not ready');
      return;
    }

    // Prevent switching to same seat
    if (_mySeatIndex == seatIndex) {
      print('⚠️ Already in this seat');
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

    // Preserve video/audio state before switching
    final wasVideoEnabled = _isVideoEnabled;
    final wasMuted = _isMuted;
    final prevCanTalk =
        _mySeatIndex != null ? _seats[_mySeatIndex!]?.canTalk : null;

    if (mounted) {
      setState(() {
        _isSwitchingSeat = true;
      });
    }

    try {
      // If already in a seat, leave it first (allows seat switching for non-hosts)
      if (_mySeatIndex != null) {
        // Leave current seat first
        try {
          await LiveStreamingService.leavePartySeat(
            liveStreamId: _currentLiveStreamId,
            seatIndex: _mySeatIndex!,
          );
          print('✅ Left seat $_mySeatIndex before switching');
        } catch (e) {
          print('⚠️ Error leaving old seat: $e');
          // Continue anyway - might already be left
        }
      }

      // Join new seat
      await LiveStreamingService.joinPartySeat(
        liveStreamId: _currentLiveStreamId,
        seatIndex: seatIndex,
        userUid: _localUid ?? 0,
        canTalk: prevCanTalk,
      );

      // Update seat index immediately for responsive UI
      if (mounted) {
        setState(() => _mySeatIndex = seatIndex);
      }

      // PERFORMANCE FIX: Set role and restore audio/video sequentially with delays
      // to prevent race conditions, instead of using Future.wait()
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Restore video state
      if (wasVideoEnabled) {
        await Future.delayed(const Duration(milliseconds: 50));
        _engine.enableVideo();
        await Future.delayed(const Duration(milliseconds: 50));
        _engine.startPreview();
        await Future.delayed(const Duration(milliseconds: 50));
        _engine.muteLocalVideoStream(false);
        print('✅ Video restored after seat switch');
      } else {
        await Future.delayed(const Duration(milliseconds: 50));
        _engine.muteLocalVideoStream(true);
      }

      // Restore audio state
      await Future.delayed(const Duration(milliseconds: 50));
      _engine.enableAudio();
      await Future.delayed(const Duration(milliseconds: 50));
      _engine.muteLocalAudioStream(wasMuted);
      await Future.delayed(const Duration(milliseconds: 50));
      _engine.setDefaultAudioRouteToSpeakerphone(true);

      // PERFORMANCE FIX: Load seats in background without awaiting
      // Reset the debounce timer to force a reload since we just joined a seat
      _lastSeatsLoadTime = null;
      _seatsLoadPending = false;
      _loadSeats().catchError((e) {
        if (!_isDisposed) {
          print('⚠️ Error loading seats after switch: $e');
        }
      });

      if (mounted) {
        ToasterService.showSuccess(
          context,
          'Switched to seat ${seatIndex + 1}',
        );
      }
      print('✅ Joined seat $seatIndex');
    } catch (e) {
      print('❌ Error joining seat: $e');
      ToasterService.showError(context, 'Failed to join seat');

      // Restore video/audio state on error
      if (wasVideoEnabled) {
        await _engine.enableVideo();
        await _engine.startPreview();
        await _engine.muteLocalVideoStream(false);
      }
    } finally {
      // Always reset switching flag, even on error
      if (mounted) {
        setState(() {
          _isSwitchingSeat = false;
        });
      }
    }
  }

  Future<void> _leaveSeat() async {
    // CRITICAL: Hosts CANNOT leave their seat in TikTok-style party mode
    // Hosts are always assigned seat 0 and can only end the live stream
    if (widget.isHost) {
      print(
        '⚠️ Hosts cannot leave their seat - they must end the live stream instead',
      );
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

    final liveStreamId =
        widget.isHost ? _currentLiveStreamId : widget.liveStream.id;
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

      // Add message locally for immediate feedback with proper author info
      final user = TokenAuthService.currentUser;
      if (user != null && mounted) {
        final senderName =
            (user.displayName != null && user.displayName!.trim().isNotEmpty)
                ? user.displayName!.trim()
                : (user.email ?? user.id);

        // Create UserModel from TokenUser for message author
        final author = UserModel(
          id: user.id,
          username: senderName,
          displayName: senderName,
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
          author: author, // Include author UserModel
          authorName: senderName,
          liveStreamId: liveStreamId,
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
      // Only show error if message wasn't cleared yet
      if (mounted && _messageController.text == text) {
        ToasterService.showError(context, 'Failed to send message');
        // Restore message if send failed
        _messageController.text = text;
      }
    }
  }

  Future<void> _leaveLive({
    bool showConfirmation = true,
    bool navigateBack = true,
  }) async {
    try {
      // For hosts: They cannot leave their seat separately - ending live automatically handles seat leaving
      // For viewers: Leave seat first if in one
      if (!widget.isHost && _mySeatIndex != null) {
        await _leaveSeat();
      }

      bool shouldLeave = true;

      // Ask confirmation before leaving live (only if requested and context is mounted)
      if (showConfirmation && mounted) {
        final result = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A1A),
                title: const Text(
                  'Leave Live Stream?',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  widget.isHost
                      ? 'Are you sure you want to end this live stream? This will end the stream for all viewers.'
                      : 'Are you sure you want to leave this live stream?',
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

      if (!shouldLeave) {
        return; // User cancelled or confirmation skipped
      }

      // For hosts, end live stream
      if (widget.isHost) {
        await _endLiveStream();
      } else if (!widget.isHost) {
        // For viewers, track leave
        await LiveStreamingService.leaveLiveStream(
          liveStreamId: widget.liveStream.id,
          userUid: _localUid ?? 0,
        );

        // Notify via WebSocket
        SocketService.instance.socket?.emit('live:left', {
          'liveStreamId': widget.liveStream.id,
          'uid': _localUid,
        });

        // Track viewer leave in backend
        await _onViewerLeave();
      }

      print('✅ Left live');

      // Navigate back if requested and context is valid
      if (navigateBack && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error leaving live: $e');
      ToasterService.showError(context, 'Failed to leave live stream');
    }
  }

  /// Silent cleanup used during dispose or forced removal (no dialogs, no navigation)
  Future<void> _cleanupOnDispose() async {
    try {
      // Viewers: leave seat if occupied
      if (!widget.isHost &&
          _mySeatIndex != null &&
          _currentLiveStreamId.isNotEmpty) {
        await LiveStreamingService.leavePartySeat(
          liveStreamId: _currentLiveStreamId,
          seatIndex: _mySeatIndex!,
        );
      }

      // Hosts are already handled in dispose via _endLiveStream()
      if (widget.isHost) return;

      // Viewers: leave live stream and notify backend/socket
      if (widget.liveStream.id.isNotEmpty) {
        await LiveStreamingService.leaveLiveStream(
          liveStreamId: widget.liveStream.id,
          userUid: _localUid ?? 0,
        );

        SocketService.instance.socket?.emit('live:left', {
          'liveStreamId': widget.liveStream.id,
          'uid': _localUid,
        });

        await _onViewerLeave();
      }
    } catch (e) {
      print('⚠️ Error during dispose cleanup: $e');
    }
  }

  /// Track viewer leave (similar to old implementation's onViewerLeave)
  Future<void> _onViewerLeave() async {
    if (widget.isHost) return; // Only for viewers

    try {
      // Update viewer status in backend
      // This should be handled by the backend API, but we can emit a socket event
      SocketService.instance.socket?.emit('live:viewer:left', {
        'liveStreamId': widget.liveStream.id,
        'userId': TokenAuthService.currentUser?.id,
        'uid': _localUid,
      });

      print('✅ Viewer leave tracked');
    } catch (e) {
      print('❌ Error tracking viewer leave: $e');
    }
  }

  /// Open host settings sheet (for own seat)
  void _openHostSettingsSheet(AudioChatUserModel seat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => _buildHostSettingsSheet(seat),
    );
  }

  /// Open user options sheet (for host to manage other users)
  void _openUserOptions(AudioChatUserModel seat) {
    if (seat.joinedUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => _buildUserOptionsSheet(seat),
    );
  }

  /// Build host settings sheet widget
  Widget _buildHostSettingsSheet(AudioChatUserModel seat) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.1,
      maxChildSize: 1.0,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'My Seat Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Mute/Unmute
              ListTile(
                leading: Icon(
                  _isMuted ? Icons.mic_off : Icons.mic,
                  color: Colors.white,
                ),
                title: Text(
                  _isMuted ? 'Unmute' : 'Mute',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _toggleMute();
                  Navigator.pop(context);
                },
              ),
              // Video On/Off
              ListTile(
                leading: Icon(
                  _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  color: Colors.white,
                ),
                title: Text(
                  _isVideoEnabled ? 'Turn Video Off' : 'Turn Video On',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _toggleVideo();
                  Navigator.pop(context);
                },
              ),
              // Switch Camera
              ListTile(
                leading: const Icon(Icons.cameraswitch, color: Colors.white),
                title: const Text(
                  'Switch Camera',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _switchCamera();
                  Navigator.pop(context);
                },
              ),
              // Leave Seat (REMOVED for hosts - hosts cannot leave their seat in TikTok-style party mode)
              // Hosts can only end the live stream, which automatically handles seat leaving
              if (!widget.isHost)
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text(
                    'Leave Seat',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    _leaveSeat();
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Build user options sheet widget (host controls for other users)
  Widget _buildUserOptionsSheet(AudioChatUserModel seat) {
    final user = seat.joinedUser;
    if (user == null) return const SizedBox.shrink();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.1,
      maxChildSize: 1.0,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // User info
              CircleAvatar(
                radius: 40,
                backgroundImage:
                    user.profileImageUrl != null
                        ? CachedNetworkImageProvider(user.profileImageUrl!)
                        : null,
                child:
                    user.profileImageUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
              ),
              const SizedBox(height: 10),
              Text(
                user.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              // Mute/Unmute user
              ListTile(
                leading: Icon(
                  seat.enabledAudio ? Icons.mic_off : Icons.mic,
                  color: Colors.white,
                ),
                title: Text(
                  seat.enabledAudio ? 'Mute User' : 'Unmute User',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _muteUser(seat);
                  Navigator.pop(context);
                },
              ),
              // Disable/Enable video
              ListTile(
                leading: Icon(
                  seat.enabledVideo ? Icons.videocam_off : Icons.videocam,
                  color: Colors.white,
                ),
                title: Text(
                  seat.enabledVideo ? 'Disable Video' : 'Enable Video',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _toggleUserVideo(seat);
                  Navigator.pop(context);
                },
              ),
              // Remove from seat
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text(
                  'Remove from Seat',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  _removeUserFromSeat(seat);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Mute/unmute a user (host action)
  Future<void> _muteUser(AudioChatUserModel seat) async {
    if (seat.joinedUserId == null) return;
    final newMutedState = !seat.enabledAudio; // toggle

    // Call backend (authoritative)
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

    // Best-effort front-end enforcement for immediate effect
    if (seat.joinedUserUid != null) {
      try {
        await _engine.muteRemoteAudioStream(
          uid: seat.joinedUserUid!,
          mute: newMutedState,
        );
      } catch (e) {
        print('⚠️ Error muting remote audio locally: $e');
      }
    }

    ToasterService.showInfo(
      context,
      newMutedState ? 'User muted' : 'User unmuted',
    );
    await _loadSeats();
  }

  /// Toggle user video (host action)
  Future<void> _toggleUserVideo(AudioChatUserModel seat) async {
    // TODO: Implement backend API call to toggle user video
    // For now, emit socket event
    final newVideoState =
        !seat.enabledVideo; // Toggle: if video enabled, disable it
    SocketService.instance.socket?.emit('live:host:toggleVideo', {
      'liveStreamId': _currentLiveStreamId,
      'seatIndex': seat.seatIndex,
      'enabled': newVideoState,
    });

    ToasterService.showInfo(
      context,
      newVideoState ? 'Video enabled' : 'Video disabled',
    );
    await _loadSeats();
  }

  /// Remove user from seat (host action)
  Future<void> _removeUserFromSeat(AudioChatUserModel seat) async {
    try {
      await LiveStreamingService.leavePartySeat(
        liveStreamId: _currentLiveStreamId,
        seatIndex: seat.seatIndex,
      );

      ToasterService.showSuccess(context, 'User removed from seat');
      await _loadSeats();
    } catch (e) {
      print('❌ Error removing user from seat: $e');
      ToasterService.showError(context, 'Failed to remove user');
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
        // For hosts: They cannot leave their seat separately - ending live automatically handles seat leaving
        // For viewers: Leave seat first if in one
        if (!widget.isHost && _mySeatIndex != null) {
          await _leaveSeat();
        }

        // Ask confirmation before leaving live
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A1A),
                title: const Text(
                  'Leave Live Stream?',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  widget.isHost
                      ? 'Are you sure you want to end this live stream? This will end the stream for all viewers.'
                      : 'Are you sure you want to leave this live stream?',
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
          // For hosts, end live stream
          if (widget.isHost) {
            await _endLiveStream();
          } else if (!widget.isHost) {
            // For viewers, track leave
            try {
              await LiveStreamingService.leaveLiveStream(
                liveStreamId: widget.liveStream.id,
                userUid: _localUid ?? 0,
              );

              // Notify via WebSocket
              SocketService.instance.socket?.emit('live:left', {
                'liveStreamId': widget.liveStream.id,
                'uid': _localUid,
              });

              // Track viewer leave in backend
              await _onViewerLeave();
            } catch (e) {
              print('⚠️ Error tracking viewer leave: $e');
            }
          }

          // Navigate back
          if (mounted) {
            Navigator.pop(context);
          }
        }

        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Transparent so background shows through
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/audio_room_background.png'),
                fit: BoxFit.cover, // Cover entire screen
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: _buildVideoGrid()),
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
                // Platform message display
                _buildPlatformMessageDisplay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build platform message display widget
  Widget _buildPlatformMessageDisplay() {
    if (_currentPlatformMessage == null) {
      return const SizedBox.shrink();
    }

    final message = _currentPlatformMessage!['message'] ?? '';
    final author = _currentPlatformMessage!['author'] ?? 'User';
    final avatarUrl = _currentPlatformMessage!['avatarUrl'] ?? '';
    final isMysteriousMan =
        _currentPlatformMessage!['isMysteriousMan'] as bool? ?? false;

    // Mask name if mysterious man
    String displayName = author;
    if (isMysteriousMan) {
      if (author.length <= 3) {
        displayName =
            '*' * (author.length - 1) + author.substring(author.length - 1);
      } else {
        displayName =
            '*' * (author.length - 3) + author.substring(author.length - 3);
      }
    }

    return Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _platformMessageAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child:
                      isMysteriousMan
                          ? Image.asset(
                            'assets/images/mysteryman.png',
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              );
                            },
                          )
                          : avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) {
                              return const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              );
                            },
                          )
                          : const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                ),
              ),
              const SizedBox(width: 10),
              // Message text
              Flexible(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: displayName,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
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
              widget.isHost
                  ? 'Starting video party...'
                  : 'Joining video party...',
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
          // Back button - triggers WillPopScope which handles seat leaving and confirmation
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
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
    final showTwoColumn = numberOfSeats == 4;
    final showThreeColumn = numberOfSeats == 6;
    final crossAxisCount = showTwoColumn ? 2 : 3;
    final childAspectRatio =
        showTwoColumn ? 1.0 : (showThreeColumn ? 0.7 : 1.1);

    return GestureDetector(
      onTap: () {
        // Toggle controls on tap
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        // Background removed from here - now handled at Scaffold level
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video grid
            Expanded(
              flex: 3,
              child: GridView.builder(
                controller: _videoGridScrollController,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 0,
                  mainAxisSpacing: 0,
                ),
                itemCount: numberOfSeats,
                itemBuilder: (context, index) {
                  final seat = _seats[index];
                  return _buildVideoCard(seat, index, showTwoColumn);
                },
              ),
            ),
            // Platform text field (host only, when enabled)
            if (widget.isHost && _showPlatformTextField)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Form(
                  key: _platformFormKey,
                  child: TextFormField(
                    controller: _platformTextController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Message Cannot be Empty";
                      }
                      return null;
                    },
                    style: TextStyle(color: Colors.blueGrey),
                    maxLength: 50,
                    maxLines: 1,
                    decoration: InputDecoration(
                      counterStyle: TextStyle(color: Colors.white),
                      errorStyle: TextStyle(
                        fontSize: 12,
                        shadows: [
                          Shadow(
                            blurRadius: 1,
                            color: Color.fromARGB(255, 151, 10, 7),
                          ),
                        ],
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          if (_platformFormKey.currentState?.validate() ??
                              false) {
                            _sendPlatformMessage(_platformTextController.text);
                          }
                        },
                        icon: Icon(Icons.send),
                      ),
                      suffixIconColor: Colors.blueGrey,
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0.5,
                        horizontal: 20,
                      ),
                      hintText: "Enter Platform Message",
                      hintStyle: TextStyle(color: Colors.blueGrey),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueGrey),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(
    AudioChatUserModel? seat,
    int seatIndex,
    bool showTwoColumn,
  ) {
    final isOccupied =
        seat != null && seat.joinedUserId != null && !seat.leftRoom;
    final isMe = _mySeatIndex == seatIndex;

    // Empty seat
    if (!isOccupied) {
      return GestureDetector(
        onTap: () {
          // Prevent multiple taps during seat switch
          if (_isSwitchingSeat) {
            return;
          }

          // Allow joining empty seat if:
          // 1. Not in a seat yet, OR
          // 2. Already in a seat (allows seat switching)
          if (_mySeatIndex == null || _mySeatIndex != seatIndex) {
            _joinSeat(seatIndex);
          }
        },
        child: Container(
          color: _getSeatColor(seatIndex, showTwoColumn),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 15,
                    width: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${seatIndex + 1}',
                        style: TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Icon(
                    Icons.chair,
                    color: Colors.white.withOpacity(0.4),
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Occupied seat
    final seatUser = seat.joinedUser;
    final enabledVideo = seat.enabledVideo;
    final enabledAudio = seat.enabledAudio;
    final isMySeat = isMe;
    final shouldShowVideo = isMySeat
        ? (_isVideoEnabled && !_isVideoDisabledByHost)
        : (enabledVideo && seat.joinedUserUid != null);

    return GestureDetector(
      onTap: () {
        // Prevent actions during seat switch
        if (_isSwitchingSeat) {
          return;
        }

        if (isMySeat) {
          // Show settings for own seat
          _openHostSettingsSheet(seat);
        } else if (widget.isHost) {
          // Show user options for host
          _openUserOptions(seat);
        }
      },
      child: Container(
        color: _getSeatColor(seatIndex, showTwoColumn),
        child: Stack(
          children: [
            // Video view or avatar
            if (shouldShowVideo && seat.joinedUserUid != null)
              _buildVideoView(seatIndex, seat.joinedUserUid!, isMySeat)
            else
              _buildAvatarView(seatUser, seatIndex),

            // Overlay content
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Seat number badge
                    Container(
                      height: 15,
                      width: 20,
                      decoration: BoxDecoration(
                        gradient:
                            isOccupied
                                ? LinearGradient(
                                  colors: [Colors.amber, Colors.yellow],
                                )
                                : null,
                        color: isOccupied ? null : Colors.transparent,
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: Center(
                        child:
                            seatIndex == 0
                                ? Icon(
                                  Icons.home_filled,
                                  color: Colors.white,
                                  size: 12,
                                )
                                : Text(
                                  '${seatIndex + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                  ),
                                ),
                      ),
                    ),
                    // Diamonds badge (if user has info)
                    if (seatUser != null)
                      Container(
                        height: 15,
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.diamond, color: Colors.pink, size: 10),
                            SizedBox(width: 2),
                            Text(
                              '${seatUser.diamonds}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Spacer(),
                // Mute indicator
                if (!enabledAudio)
                  Container(
                    height: 35,
                    width: 35,
                    margin: EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mic_off, color: Colors.red, size: 20),
                  ),
                // User name
                Padding(
                  padding: EdgeInsets.only(left: 3, bottom: 5, right: 3),
                  child: Text(
                    seatUser?.displayName ?? 'User',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Leave seat button (for own seat)
            if (isMySeat && !widget.isHost)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _leaveSeat(),
                  child: Container(
                    height: 25,
                    width: 25,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: Colors.white, size: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSeatColor(int index, bool showTwoColumn) {
    if (showTwoColumn) {
      return (index == 0 || index == 3)
          ? Colors.white.withOpacity(0.1)
          : Colors.black.withOpacity(0.2);
    } else {
      return (index % 2 == 0)
          ? Colors.white.withOpacity(0.1)
          : Colors.black.withOpacity(0.2);
    }
  }

  Widget _buildVideoView(int seatIndex, int uid, bool isMySeat) {
    if (isMySeat) {
      // Local video view
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else {
      // Remote video view
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: uid),
          connection: RtcConnection(
            channelId: widget.liveStream.streamingChannel,
          ),
        ),
      );
    }
  }

  Widget _buildAvatarView(UserModel? seatUser, int seatIndex) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background blur
          if (seatUser != null && seatUser.profileImageUrl != null)
            CachedNetworkImage(
              imageUrl: seatUser.profileImageUrl!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            )
          else
            Container(color: Colors.black54),
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    backgroundImage:
                        seatUser != null && seatUser.profileImageUrl != null
                            ? CachedNetworkImageProvider(
                              seatUser.profileImageUrl!,
                            )
                            : null,
                    child:
                        (seatUser == null || seatUser.profileImageUrl == null)
                            ? Icon(Icons.person, color: Colors.white, size: 40)
                            : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSection() {
    return Container(
      height: 150,
      // Remove gradient decoration - background image will show through
      // Add semi-transparent overlay for better text readability
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // Semi-transparent overlay
      ),
      child: Column(
        children: [
          // Messages
          Expanded(
            child:
                _messages.isEmpty
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${message.author?.bestDisplayName ?? message.authorName ?? message.author?.username ?? message.authorId}: ',
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
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                      ),
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
        // Semi-transparent overlay so background image shows through
        color: Colors.black.withOpacity(0.4),
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

            // Platform speaker button (host only)
            if (widget.isHost)
              _buildControlButton(
                icon: Icons.campaign,
                label: 'Platform',
                onTap: () {
                  if (_platformSpeakerNumber == 0) {
                    ToasterService.showInfo(
                      context,
                      'No platform messages available',
                    );
                    return;
                  }
                  setState(() {
                    _showPlatformTextField = !_showPlatformTextField;
                  });
                },
                isActive: _platformSpeakerNumber > 0,
                badge:
                    _platformSpeakerNumber > 0 ? _platformSpeakerNumber : null,
              ),

            // Leave seat button (for hosts in a seat)
            // NOTE: In TikTok-style party mode, hosts should not leave their seat
            // as they are always assigned seat 0. Leaving seat means ending the live.
            _buildControlButton(
              icon: Icons.exit_to_app,
              label: 'Leave Seat',
              onTap: () async {
                // For hosts, leaving seat means ending the live stream (TikTok party mode behavior)
                if (widget.isHost) {
                  _leaveLive(); // This will handle seat leaving and live ending
                } else {
                  // For non-hosts, just leave the seat
                  await _leaveSeat();
                }
              },
              isActive: false,
              isDestructive: true,
            ),
          ] else ...[
            // Join seat button
            _buildControlButton(
              icon: Icons.chair,
              label: 'Join Seat',
              onTap: () {
                final emptySeat =
                    _seats.entries
                        .firstWhere(
                          (e) =>
                              e.value.joinedUserId == null || e.value.leftRoom,
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
    int? badge,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (badge != null && badge > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badge.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
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
    // Set disposed flag first to prevent any pending operations
    _isDisposed = true;

    // Remove widget lifecycle observer
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      print('⚠️ Error removing observer: $e');
    }

    // Cancel all timers
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;

    // Mark live as inactive to stop heartbeat
    _isLiveActive = false;

    // Unregister socket event listeners to prevent memory leaks
    final socket = SocketService.instance.socket;
    if (socket != null) {
      try {
        socket.off('live:seat:updated');
        socket.off('live:host:action');
        socket.off('live:message:new');
        socket.off('live:platform:message');
        socket.off('live:ended');
        socket.off('live:user:removed');
        print('✅ Socket listeners unregistered');
      } catch (e) {
        print('⚠️ Error unregistering socket listeners: $e');
      }
    }

    // Dispose all controllers
    try {
      _messageController.dispose();
      _messageScrollController.dispose();
      _videoGridScrollController.dispose();
      _platformTextController.dispose();
      _platformMessageController.dispose();
    } catch (e) {
      print('⚠️ Error disposing controllers: $e');
    }

    // IMPORTANT: For hosts, end live stream FIRST before any navigation
    // This ensures the live stream is marked as ended in backend
    if (widget.isHost) {
      _endLiveStream().catchError((e) {
        print('⚠️ Error ending live stream: $e');
      });
    }

    // Leave live stream (silent) for viewers; hosts already ended above
    _cleanupOnDispose().catchError((e) {
      print('⚠️ Error leaving live during dispose: $e');
    });

    // Clean up Agora engine
    if (_engineCreated) {
      try {
        if (_engineInitialized) {
          _engine.leaveChannel();
        }
        _engine.release();
        print('✅ Agora engine cleaned up');
      } catch (e) {
        print('⚠️ Error releasing Agora engine: $e');
      }
    } else {
      print('ℹ️ Skipping Agora engine cleanup: not created');
    }

    // Clean up wakelock and system UI
    try {
      WakelockPlus.disable();
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    } catch (e) {
      print('⚠️ Error cleaning up system settings: $e');
    }

    print('✅ Video party disposed');

    super.dispose();
  }
}
