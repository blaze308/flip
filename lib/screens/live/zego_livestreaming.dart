import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../../models/live_stream_model.dart';
import '../../models/user_model.dart';
import '../../services/live_streaming_service.dart';
import '../../services/token_auth_service.dart';
import '../../widgets/custom_toaster.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/circular_icon_container.dart';

class ZegoLivestreaming extends StatefulWidget {
  final UserModel? mUser;
  final String liveID;
  final bool isHost;
  final TokenUser currentUser;
  final SharedPreferences preferences;
  final LiveStreamModel mLiveStreamingModel;

  static String route = "/home/live/streaming";

  ZegoLivestreaming({
    Key? key,
    required this.liveID,
    this.isHost = false,
    required this.currentUser,
    required this.preferences,
    required this.mLiveStreamingModel,
    this.mUser,
  }) : super(key: key);

  @override
  State<ZegoLivestreaming> createState() => _ZegoLivestreamingState();
}

class _ZegoLivestreamingState extends State<ZegoLivestreaming>
    with TickerProviderStateMixin {
  final liveStateNotifier = ValueNotifier<ZegoLiveStreamingState>(
    ZegoLiveStreamingState.idle,
  );

  final PKStateNotifier = ValueNotifier<ZegoLiveStreamingState>(
    ZegoLiveStreamingState.inPKBattle,
  );

  final requestingHostsMapRequestIDNotifier =
      ValueNotifier<Map<String, List<String>>>({});
  final requestIDNotifier = ValueNotifier<String>('');
  // PKEvents? pkEvents;
  bool isInPKBattle = false;

  int appID = 0;
  String appSign = '';
  bool _credentialsLoaded = false;
  bool _zegoConnected = false; // Track if Zego actually connected
  bool _liveStreamCreated =
      false; // Track if live stream was created in backend
  String? _createdLiveStreamId; // Store the created live stream ID
  Timer? _connectionTimeoutTimer; // Timeout if Zego doesn't connect
  Timer? _heartbeatTimer; // Heartbeat to keep stream alive
  AnimationController? _animationController;

  String linkToShare = "";

  String? entranceUrl;
  bool showEntranceEffect = false;

  createLink(String liveID) async {
    try {
      // Create deep link for live stream
      final shareUrl = 'https://flip-backend-mnpg.onrender.com/live/$liveID';
      setState(() {
        linkToShare = shareUrl;
      });
      shareLink();

      // Option 2: If you want to use a URL shortening service
      // String shortenedUrl = await appLinksService.createSharableUrl(
      //     liveID, AppLinksService.keyLinkLive);
      //
      // if (shortenedUrl.isNotEmpty) {
      //   // QuickHelp.hideLoadingDialog(context);
      //   setState(() {
      //     linkToShare = shortenedUrl;
      //   });
      //   shareLink();
      // } else {
      //   // QuickHelp.hideLoadingDialog(context);
      //   ToasterService.showError(context, 'Could not generate share link');
      // }
    } catch (e) {
      // QuickHelp.hideLoadingDialog(context);
      ToasterService.showError(context, 'Could not generate share link');
    }
  }

  shareLink() async {
    await Share.share(linkToShare);
  }

  @override
  void initState() {
    super.initState();
    // Get ZegoCloud credentials - fail if not found
    try {
      final appIdStr = dotenv.env['ZEGO_APP_ID'];
      final appSignStr = dotenv.env['ZEGO_APP_SIGN'];

      if (appIdStr == null || appSignStr == null) {
        throw Exception('ZegoCloud credentials not found in .env file');
      }

      appID = int.parse(appIdStr);
      appSign = appSignStr;

      if (appID == 0 || appSign.isEmpty) {
        throw Exception('ZegoCloud credentials are invalid');
      }
      _credentialsLoaded = true;
    } catch (e) {
      print('❌ Error loading Zego credentials: $e');
      // Clean up the live stream that was created
      // No live stream is created yet; ensure any pending creation is cleaned up.
      _endLiveStream();
      // Show error and prevent live stream from starting
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ToasterService.showError(
            context,
            'Live streaming is not configured. Please contact support.',
          );
          Navigator.pop(context);
        }
      });
      return; // Exit early - don't initialize live stream
    }

    // Only proceed if credentials are loaded
    if (!_credentialsLoaded) {
      return;
    }

    WakelockPlus.enable();
    _animationController = AnimationController.unbounded(vsync: this);

    // pkEvents = PKEvents(
    //   requestIDNotifier: requestIDNotifier,
    //   requestingHostsMapRequestIDNotifier: requestingHostsMapRequestIDNotifier,
    //   mLiveStreamingModel: widget.mLiveStreamingModel,
    //   context: context,
    // );

    // ZegoGiftManager().cache.cacheAllFiles(giftItemList);

    // ZegoGiftManager().service.recvNotifier.addListener(onGiftReceived);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // ZegoGiftManager().service.init(
      //       appID: appID,
      //       liveID: widget.liveID,
      //       localUserID: widget.currentUser.username!,
      //       localUserName: widget.currentUser.username!,
      //     );
    });

    // Only proceed with live stream initialization if credentials are loaded
    if (!_credentialsLoaded) {
      return;
    }

    //migrated
    checkPlatformSpeakerNumber();
    getCode();

    // QuickHelp.saveCurrentRoute(route: LiveStreamingScreen.route);

    liveStreamingModel = widget.mLiveStreamingModel;
    // Live stream will be created AFTER successful Zego connection (in onConnected callback)
    if (widget.isHost) {
      // Set a timeout - if Zego doesn't connect within 30 seconds, navigate back
      _connectionTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!_zegoConnected && mounted) {
          print('⏱️ Zego connection timeout');
          ToasterService.showError(
            context,
            'Failed to start live stream. Please try again.',
          );
          Navigator.pop(context);
        }
      });
    }
  }

  /// Create live stream in backend AFTER successful Zego connection
  Future<void> _createLiveStream() async {
    if (!widget.isHost || _liveStreamCreated) return;

    try {
      final user = widget.currentUser;
      final liveStream = await LiveStreamingService.createLiveStream(
        liveType: 'live',
        streamingChannel: widget.liveID,
        authorUid: int.parse(user.id.hashCode.toString().substring(0, 8)),
      );

      setState(() {
        _liveStreamCreated = true;
        _createdLiveStreamId = liveStream.id;
        liveStreamingModel = liveStream;
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
    if (!_liveStreamCreated || _createdLiveStreamId == null) return;

    try {
      await LiveStreamingService.endLiveStream(_createdLiveStreamId!);
      print('✅ Live stream ended: $_createdLiveStreamId');
    } catch (e) {
      print('❌ Error ending live stream: $e');
    }
  }

  getUserbyObjectId(String objectId) async {
    // TODO: Implement user lookup by ID in flip app
    // For now, return null as this functionality may not be needed
    print("getUserbyObjectId called with: $objectId");
    return null;
  }

  String? languageCode;
  int _platformSpeakerNumber = 0;
  late LiveStreamModel liveStreamingModel;

  // bool? _canSendPlatformMessage = false;
  // bool checkPlatformSpeakerNumber() {
  //   if (_platformSpeakerNumber > 0) {
  //     setState(() {
  //       _canSendPlatformMessage = true;
  //     });
  //     return true;
  //   } else {
  //     setState(() {
  //       _canSendPlatformMessage = false;
  //     });
  //     return false;
  //   }
  // }
  bool _canSendPlatformMessage = false;

  bool checkPlatformSpeakerNumber() {
    final bool canSend = _platformSpeakerNumber > 0;
    if (_canSendPlatformMessage != canSend) {
      setState(() {
        _canSendPlatformMessage = canSend;
      });
    }
    return canSend;
  }

  void _onSendPlatformMessage(String message) async {
    if (!_canSendPlatformMessage) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Cannot Send Message'),
            content: Text(
              'You are not allowed to send a platform message at this time.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      if (formKey.currentState!.validate()) {
        sendPlatformMessage(message);
      }
      platformTextEditingController.text = "";
      _showTextField = false;
    }
  }

  void sendPlatformMessage(String message) async {
    // TODO: Implement platform message sending via backend API
    // For now, just show success
    ToasterService.showSuccess(context, 'Platform message sent');
    setState(() {
      _platformSpeakerNumber =
          _platformSpeakerNumber > 0 ? _platformSpeakerNumber - 1 : 0;
      _showTextField = false;
    });
  }

  Widget platformMessageAvatar({
    String? platformMessage,
    String? author,
    String? avatarUrl,
    bool? isMysteriousMan,
  }) {
    if (platformMessage == null ||
        author == null ||
        avatarUrl == null ||
        isMysteriousMan == null) {
      return SizedBox();
    }

    String? maskedName;
    if (isMysteriousMan == true) {
      String fullName = author;
      if (fullName.length <= 3) {
        maskedName =
            '*' * (fullName.length - 1) +
            fullName.substring(fullName.length - 1);
      } else {
        maskedName =
            '*' * (fullName.length - 3) +
            fullName.substring(fullName.length - 3);
      }
    } else {
      maskedName = author;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.5),
            Colors.black.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF4ECDC4).withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4ECDC4).withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(50),
            ),
            child:
                isMysteriousMan
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.asset(
                        "assets/images/mysteryman.png",
                        width: 10,
                        height: 10,
                        fit: BoxFit.cover,
                      ),
                    )
                    : CircleAvatar(
                      radius: 15,
                      backgroundImage: NetworkImage(avatarUrl),
                    ),
          ),
          Flexible(
            child: RichText(
              maxLines: 1,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: isMysteriousMan ? maskedName : author,
                    style: const TextStyle(color: Colors.orange),
                  ),
                  TextSpan(text: " "),
                  TextSpan(
                    text: platformMessage,
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  late final Animation<Offset> _offsetAnimation = Tween<Offset>(
    begin: Offset(3.0, 0.0),
    end: Offset(-1.0, 0.0),
  ).animate(
    CurvedAnimation(
      parent: _platformMessageController,
      curve: Curves.easeInOut,
    ),
  );

  late final AnimationController _platformMessageController =
      AnimationController(duration: Duration(seconds: 30), vsync: this);

  bool _showTextField = false;
  String liveCounter = "0";
  String diamondsCounter = "0";
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  TextEditingController platformTextEditingController = TextEditingController();

  List<UserModel> liveViewers = [];

  getCode() async {
    // TODO: Get country from user profile if needed
    // await getLanguageCode(widget.currentUser.country);
  }

  Map<String, String> generateCountryLanguageMap() {
    return {
      'Ghana': 'en',
      'Nigeria': 'en',
      'South Africa': 'en',
      'Kenya': 'en',
      'Cameroon': 'en',
      'Brasil': 'pt',
      'Bolivia': 'es',
      'Angola': 'pt',
      'Pakistan': 'ur',
      'Philipinas': 'en',
      'Guinea Ecuatorial': 'es',
      'भारत': 'hi',
      'India': 'en',
      'Côte d\'Ivoire': 'fr',
      'Indonesia': 'id',
      'United Kingdom': 'en',
    };
  }

  String? getLanguageCode(String? country) {
    Map<String, String> countryLanguageMap = generateCountryLanguageMap();

    if (countryLanguageMap.containsKey(country)) {
      print("countryLanguageMap: ${countryLanguageMap[country]}");
      setState(() {
        languageCode = countryLanguageMap[country];
      });
      return countryLanguageMap[country];
    }
    return null;
  }

  bool translate = false;
  // TODO: Implement Google Translator if needed
  // GoogleTranslator translator = GoogleTranslator();

  Future<String> translatedText(String text) async {
    if (text.length < 3) {
      return text;
    }
    // TODO: Implement translation
    return text;
  }

  Widget getTranslatedMessage(String text) {
    return FutureBuilder(
      future: translatedText(text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            "Loading Translation",
            style: TextStyle(color: Colors.white),
          );
        } else if (snapshot.hasError) {
          return Text(
            "${snapshot.error}",
            style: TextStyle(color: Colors.white),
          );
        } else {
          return Text(
            snapshot.data!,
            style: TextStyle(color: Colors.white, fontSize: 13.5),
          );
        }
      },
    );
  }

  /// Start heartbeat timer to keep live stream status updated
  void _startHeartbeat() {
    _heartbeatTimer?.cancel(); // Cancel any existing timer
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (mounted && _zegoConnected && widget.isHost) {
        try {
          // Update stream status to show it's still active
          await LiveStreamingService.updateLiveStreamStatus(
            widget.mLiveStreamingModel.id,
            streaming: true,
            viewersCount: liveViewers.length,
          );
          print("💓 Live stream heartbeat sent");
        } catch (e) {
          print("❌ Heartbeat failed: $e");
        }
      }
    });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void dispose() {
    // Cancel all timers
    _connectionTimeoutTimer?.cancel();
    _stopHeartbeat();

    // End live stream if it was created (only for hosts)
    if (widget.isHost && _liveStreamCreated) {
      _endLiveStream();
    }

    // ZegoGiftManager().service.recvNotifier.removeListener(onGiftReceived);
    // ZegoGiftManager().service.uninit();
    _animationController!.dispose();
    _platformMessageController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  bool following = false;

  void followOrUnfollow({UserModel? user}) async {
    if (widget.mUser == null) return;

    // TODO: Implement follow/unfollow via ProfileService
    // For now, just toggle local state
    setState(() {
      following = !following;
    });

    print("Follow/unfollow operation completed");
  }

  @override
  Widget build(BuildContext context) {
    //PK Config
    // final PkWidgets pkWidgets = PkWidgets();
    ZegoLiveStreamingPKBattleConfig pk() {
      return ZegoLiveStreamingPKBattleConfig(
        mixerLayout: null, // TODO: Configure PK layout properly
        topBuilder: (context, hosts, extraInfo) {
          // Size size = MediaQuery.of(context).size;
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Stack(
              children: [
                //todo
                // Positioned(
                //     left: size.width * 0.25,
                //     top: 15,
                //     child: pkWidgets.TreasureWidget(widget.currentUser)),
                // Center(child: pkWidgets.PKTimerWidget()),
              ],
            ),
          );
        },
        // bottomBuilder: (context, hosts, extraInfo) {
        //   return Stack(
        //     children: [
        //       Center(
        //         child: IconButton(
        //             onPressed: () {
        //               _startHeartAnimation();
        //               print("onTap");
        //             },
        //             icon: Icon(Icons.favorite)),
        //       ),
        //       Stack(
        //         children: _hearts,
        //       ),
        //     ],
        // );
        // },
        foregroundBuilder: (context, hosts, extraInfo) {
          // Stack(
          //             alignment: AlignmentDirectional.center,
          //             children: [
          //               QuickActions.avatarWidget(
          //                 widget.currentUser!,
          //                 width: size.width / 7,
          //                 height: size.width / 7,
          //                 margin: EdgeInsets.only(top: 15, bottom: 15),
          //                 hideAvatarFrame: true,
          //               ),
          //               if (widget.currentUser!.getAvatarFrame != null &&
          //                   widget.currentUser!.getCanUseAvatarFrame!)
          //                 ContainerCorner(
          //                   borderWidth: 0,
          //                   width: size.width / 5,
          //                   height: size.width / 5,
          //                   child: CachedNetworkImage(
          //                     imageUrl:
          //                         widget.currentUser!.getAvatarFrame!.url!,
          //                     imageBuilder: (context, imageProvider) =>
          //                         Container(
          //                       decoration: BoxDecoration(
          //                         shape: BoxShape.circle,
          //                         image: DecorationImage(
          //                             image: imageProvider, fit: BoxFit.fill),
          //                       ),
          //                     ),
          //                   ),
          //                 ),
          //             ],
          //           )
          return Container();
        },
        hostReconnectingBuilder: (context, host, extraInfo) {
          return Container();
        },
        topPadding: 100,
      );
    }

    final config =
        (widget.isHost
              ? (ZegoUIKitPrebuiltLiveStreamingConfig.host(
                  plugins: [ZegoUIKitSignalingPlugin()],
                )
                //  on host can control pk
                ..video = ZegoUIKitVideoConfig.preset1080P()
                ..foreground = giftForeground())
              : ZegoUIKitPrebuiltLiveStreamingConfig.audience(
                plugins: [ZegoUIKitSignalingPlugin()],
              ))
          ..foreground = giftForeground()
          ..mediaPlayer.supportTransparent = true
          ..audioVideoView.foregroundBuilder = foregroundBuilder
          ..background = Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF667EEA).withOpacity(0.3), // Light blue
                  const Color(0xFF764BA2).withOpacity(0.3), // Purple
                  const Color(0xFFF093FB).withOpacity(0.2), // Pink
                  const Color(0xFFF5576C).withOpacity(0.2), // Red-pink
                ],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          )
          ..pkBattle = pk()
          ..avatarBuilder = (
            BuildContext context,
            Size size,
            ZegoUIKitUser? user,
            Map extraInfo,
          ) {
            if (user == null) return const SizedBox();

            final displayName =
                user.name.trim().isNotEmpty ? user.name.trim() : 'Guest';
            final initial = displayName[0].toUpperCase();
            final avatarUrl = (extraInfo['avatar'] ?? '') as String;
            final double dim = size.width > 0 ? size.width : 36;

            if (avatarUrl.isNotEmpty) {
              return ClipOval(
                child: Image.network(
                  avatarUrl,
                  width: dim,
                  height: dim,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => _buildAvatarPlaceholder(dim, initial),
                ),
              );
            }

            return _buildAvatarPlaceholder(dim, initial);
          }
          ..inRoomMessage = ZegoLiveStreamingInRoomMessageConfig(
            notifyUserJoin: true,
            notifyUserLeave: true,
            itemBuilder: (context, message, extraInfo) {
              String author = message.user.name;
              String inRoomMessage = message.message;

              // Simple message widget without Parse dependencies
              // Custom chat message style matching AgoraPartyScreen
              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${author}: ',
                        style: const TextStyle(
                          color: Color(0xFF4ECDC4),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      WidgetSpan(
                        child:
                            translate
                                ? getTranslatedMessage(inRoomMessage)
                                : Text(
                                  inRoomMessage,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
          ..video = ZegoUIKitVideoConfig.preset1080P()
          ..effect.voiceChangeEffect =
              ZegoLiveStreamingEffectConfig().voiceChangeEffect
          ..audioVideoView.showAvatarInAudioMode = true
          ..audioVideoView.showSoundWavesInAudioMode = false
          ..bottomMenuBar = ZegoLiveStreamingBottomMenuBarConfig(
            showInRoomMessageButton: true,
            buttonStyle: ZegoLiveStreamingBottomMenuBarButtonStyle(
              requestCoHostButtonText: "",
              endCoHostButtonIcon: _buildModernIconButton(Icons.person_remove),
              cancelRequestCoHostButtonIcon: _buildModernIconButton(
                Icons.close,
              ),
              cancelRequestCoHostButtonText: "Cancel Co-Host Request",
              endCoHostButtonText: "End Co-Host",
              soundEffectButtonIcon: _buildModernIconButton(Icons.music_note),
              switchCameraButtonIcon: _buildModernIconButton(
                Icons.cameraswitch,
              ),
              toggleCameraOffButtonIcon: _buildModernIconButton(
                Icons.videocam_off,
              ),
              toggleMicrophoneOnButtonIcon: _buildModernIconButton(Icons.mic),
              toggleMicrophoneOffButtonIcon: _buildModernIconButton(
                Icons.mic_off,
              ),
              toggleCameraOnButtonIcon: _buildModernIconButton(Icons.videocam),
              leaveButtonIcon: _buildModernIconButton(Icons.exit_to_app),
              toggleScreenSharingOnButtonIcon: _buildModernIconButton(
                Icons.stop_screen_share,
              ),
              toggleScreenSharingOffButtonIcon: _buildModernIconButton(
                Icons.screen_share,
              ),
              chatEnabledButtonIcon: _buildModernIconButton(Icons.chat_bubble),
              beautyEffectButtonIcon: _buildModernIconButton(
                Icons.face_retouching_natural,
              ),
              requestCoHostButtonIcon: _buildModernIconButton(Icons.person_add),
            ),
            maxCount: 3, // allow more buttons to show for guests
            audienceButtons: [
              // ZegoLiveStreamingMenuBarButtonName.chatButton,
              ZegoLiveStreamingMenuBarButtonName.coHostControlButton,
            ],
            // audienceExtendButtons: [giftButton, translateButton, shareButton],
            hostButtons: [
              ZegoLiveStreamingMenuBarButtonName.toggleMicrophoneButton,
              ZegoLiveStreamingMenuBarButtonName.toggleCameraButton,
              ZegoLiveStreamingMenuBarButtonName.switchCameraButton,
              ZegoLiveStreamingMenuBarButtonName.beautyEffectButton,
              ZegoLiveStreamingMenuBarButtonName.soundEffectButton,
              ZegoLiveStreamingMenuBarButtonName.toggleScreenSharingButton,
            ],
            // hostExtendButtons: [translateButton, shareButton],
            coHostButtons: [
              ZegoLiveStreamingMenuBarButtonName.toggleMicrophoneButton,
              ZegoLiveStreamingMenuBarButtonName.beautyEffectButton,
              ZegoLiveStreamingMenuBarButtonName.soundEffectButton,
              ZegoLiveStreamingMenuBarButtonName.toggleScreenSharingButton,
            ],
            // coHostExtendButtons: [translateButton, shareButton],
          )
          ..memberButton = ZegoLiveStreamingMemberButtonConfig(
            builder: (memberCount) {
              return Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: const Color(0xFF4ECDC4).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility,
                      color: const Color(0xFF4ECDC4),
                      size: 18,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      "$memberCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          )
          ..topMenuBar = ZegoLiveStreamingTopMenuBarConfig(
            height: 50,
            hostAvatarBuilder: (host) {
              return Container(
                height: 40,
                padding: const EdgeInsets.only(right: 4.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4ECDC4).withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ECDC4).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar
                    Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF4ECDC4),
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage:
                            widget.currentUser.photoURL != null
                                ? CachedNetworkImageProvider(
                                  widget.currentUser.photoURL!,
                                )
                                : null,
                        child:
                            widget.currentUser.photoURL == null
                                ? const Icon(
                                  Icons.person,
                                  size: 20,
                                  color: Colors.white,
                                )
                                : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Name
                    Flexible(
                      child: Text(
                        widget.currentUser.displayName ?? widget.currentUser.id,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Follow button (if not me)
                    if (!widget.isHost)
                      GestureDetector(
                        onTap: () => followOrUnfollow(user: widget.mUser),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4ECDC4).withOpacity(0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            "Follow",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              );
            },
            // showCloseButton: true,
            buttons: [
              // ZegoLiveStreamingMenuBarButtonName.leaveButton,
              // ZegoLiveStreamingMenuBarButtonName.minimizingButton,
              // ZegoLiveStreamingMenuBarButtonName.pipButton,
            ],
          );

    Future<bool> showLiveExitDialog({
      required BuildContext context,
      required bool isHost,
      required LiveStreamModel liveStreamingModel,
    }) async {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.0),
                ),
                backgroundColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                content: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A1A2E).withOpacity(0.95),
                        const Color(0xFF16213E).withOpacity(0.95),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25.0),
                    border: Border.all(
                      color: const Color(0xFF4ECDC4).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ECDC4).withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B6B).withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Exit Live Streaming",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Are you sure you want to exit the live streaming session?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                shadowColor: Colors.transparent,
                              ).copyWith(
                                backgroundColor: MaterialStateProperty.all(
                                  const Color(0xFFFF4757),
                                ),
                              ),
                              child: Text(
                                isHost ? "End Live" : "Leave Live",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () async {
                                if (isHost) {
                                  try {
                                    await LiveStreamingService.endLiveStream(
                                      liveStreamingModel.id,
                                    );
                                  } catch (e) {
                                    debugPrint('Error ending live stream: $e');
                                  }
                                }
                                if (mounted && context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ) ??
          false; // Return false if null is returned
    }

    Size size = MediaQuery.sizeOf(context);
    // TODO: Implement mysterious man feature if needed
    bool isMysteriousMan = false;

    String? maskedName =
        widget.currentUser.displayName ?? widget.currentUser.id;

    return SafeArea(
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F0F23), // Deep dark blue
                Color(0xFF1A1A2E), // Dark blue-gray
                Color(0xFF16213E), // Navy blue
                Color(0xFF0F3460), // Deep teal-blue
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              ZegoUIKitPrebuiltLiveStreaming(
                appID: appID,
                appSign: appSign,
                userID: widget.currentUser.id,
                userName:
                    (isMysteriousMan == true && !widget.isHost)
                        ? maskedName
                        : widget.currentUser.displayName ??
                            widget.currentUser.id,
                liveID: widget.liveID,
                config: config,
                events: ZegoUIKitPrebuiltLiveStreamingEvents(
                  onError: (error) {
                    print('❌ Zego error: $error');
                    // If live stream was created, end it
                    if (_liveStreamCreated) {
                      _endLiveStream();
                    }
                    // TODO: Implement LiveEndReportScreen navigation
                    Navigator.pop(context);
                  },
                  onEnded:
                      (event, defaultAction) => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  Container(), // TODO: Implement LiveEndReportScreen
                        ),
                      ),
                  onLeaveConfirmation: (
                    ZegoLiveStreamingLeaveConfirmationEvent event,

                    /// defaultAction to return to the previous page
                    Future<bool> Function() defaultAction,
                  ) async {
                    return showLiveExitDialog(
                      isHost: widget.isHost,
                      context: context,
                      liveStreamingModel: widget.mLiveStreamingModel,
                    );
                  },
                  user: ZegoLiveStreamingUserEvents(
                    onEnter: (p0) async {
                      print("testing live user entering p0 ${p0}");

                      String userId = p0.id;
                      // TODO: Implement entrance effect if needed
                      print("User entered: $userId");
                    },
                    onLeave: (p0) async {
                      print("testing live user leaving p0 ${p0}");
                    },
                  ),
                  duration: ZegoLiveStreamingDurationEvents(
                    onUpdated: (p0) {
                      if (p0.inSeconds >= 30 * 60) {
                        ZegoUIKitPrebuiltLiveStreamingController().leave(
                          context,
                        );
                      }
                    },
                  ),
                  // pk: pkEvents?.event,
                  pk: ZegoLiveStreamingPKEvents(
                    onIncomingRequestReceived: (event, defaultAction) {
                      debugPrint(
                        'custom event, onIncomingPKBattleRequestReceived, event:$event',
                      );
                      defaultAction.call();
                    },
                    onIncomingRequestCancelled: (event, defaultAction) {
                      debugPrint(
                        'custom event, onIncomingPKBattleRequestCancelled, event:$event',
                      );
                      defaultAction.call();

                      requestIDNotifier.value = '';

                      removeRequestingHostsMap(event.requestID);
                    },
                    onIncomingRequestTimeout: (event, defaultAction) {
                      debugPrint(
                        'custom event, onIncomingPKBattleRequestTimeout, event:$event',
                      );
                      defaultAction.call();

                      requestIDNotifier.value = '';

                      removeRequestingHostsMap(event.requestID);
                    },
                    onOutgoingRequestAccepted: (event, defaultAction) async {
                      debugPrint(
                        'custom event, onOutgoingPKBattleRequestAccepted, event:$event',
                      );
                      defaultAction.call();

                      removeRequestingHostsMapWhenRemoteHostDone(
                        event.requestID,
                        event.fromHost.id,
                      );
                    },
                    onOutgoingRequestRejected: (event, defaultAction) {
                      debugPrint(
                        'custom event, onOutgoingPKBattleRequestRejected, event:$event',
                      );
                      defaultAction.call();

                      removeRequestingHostsMapWhenRemoteHostDone(
                        event.requestID,
                        event.fromHost.id,
                      );
                    },
                    onOutgoingRequestTimeout: (event, defaultAction) {
                      debugPrint(
                        'custom event, onOutgoingPKBattleRequestTimeout, event:$event',
                      );

                      removeRequestingHostsMapWhenRemoteHostDone(
                        event.requestID,
                        event.fromHost.id,
                      );

                      defaultAction.call();
                    },
                    onEnded: (event, defaultAction) async {
                      debugPrint('custom event, onPKBattleEnded, event:$event');
                      defaultAction.call();

                      requestIDNotifier.value = '';

                      removeRequestingHostsMapWhenRemoteHostDone(
                        event.requestID,
                        event.fromHost.id,
                      );
                    },
                    onUserOffline: (event, defaultAction) async {
                      debugPrint('custom event, onUserOffline, event:$event');
                      defaultAction.call();

                      removeRequestingHostsMapWhenRemoteHostDone(
                        event.requestID,
                        event.fromHost.id,
                      );
                    },
                    onUserQuited: (event, defaultAction) async {
                      debugPrint('custom event, onUserQuited, event:$event');
                      defaultAction.call();

                      if (event.fromHost.id == ZegoUIKit().getLocalUser().id) {
                        requestIDNotifier.value = '';
                      }

                      removeRequestingHostsMapWhenRemoteHostDone(
                        event.requestID,
                        event.fromHost.id,
                      );
                    },
                    onUserJoined: (ZegoUIKitUser user) {
                      debugPrint('custom event, onUserJoined:$user');
                    },
                    onUserDisconnected: (ZegoUIKitUser user) {
                      debugPrint('custom event, onUserDisconnected:$user');
                    },
                    onUserReconnecting: (ZegoUIKitUser user) {
                      debugPrint('custom event, onUserReconnecting:$user');
                    },
                    onUserReconnected: (ZegoUIKitUser user) {
                      debugPrint('custom event, onUserReconnected:$user');
                    },
                  ),
                  onStateUpdated: (state) async {
                    // liveStateNotifier.value = state;
                    // PKStateNotifier.value = state;

                    if (state == ZegoLiveStreamingState.idle) {
                      print("liveStreaming is idle");
                      developer.log("liveStreaming is idle");
                    }

                    // Track when Zego actually connects (not idle means connected)
                    if (state != ZegoLiveStreamingState.idle &&
                        !_zegoConnected) {
                      _zegoConnected = true;
                      // Cancel timeout since we connected successfully
                      _connectionTimeoutTimer?.cancel();

                      // Create live stream in backend AFTER successful connection
                      if (widget.isHost) {
                        await _createLiveStream();
                      }

                      // Start heartbeat to keep stream alive
                      _startHeartbeat();

                      print("✅ Zego connected - Live stream is now active");
                      developer.log(
                        "✅ Zego connected - Live stream is now active",
                      );
                    }

                    // Additional logging for connection states
                    if (state != ZegoLiveStreamingState.idle) {
                      print("🔄 Zego state: $state");
                    }

                    if (state == ZegoLiveStreamingState.inPKBattle) {
                      setState(() {
                        isInPKBattle = true;
                      });
                      print("PKBattle in Session");
                      developer.log("PKBattle in Session");
                    }
                  },
                  topMenuBar: ZegoLiveStreamingTopMenuBarEvents(
                    onHostAvatarClicked: (host) async {
                      String hostId = host.id;
                      // TODO: Implement host profile view
                      print("Host avatar clicked: $hostId");
                    },
                  ),
                ),
              ),

              //PK Battle Invite Button
              // if (widget.isHost == true)
              //   Positioned(
              //     top: 150,
              //     left: 10,
              //     child: GestureDetector(
              //       onTap: () {
              //         openPKSettingSheet();
              //       },
              //       child: Container(
              //         padding: const EdgeInsets.all(5.0),
              //         child: Image.asset(
              //           "assets/images/PK_invite.png",
              //           width: 60,
              //           height: 60,
              //         ),
              //       ),
              //     ),
              //   ),
              if (isInPKBattle == true)
                Positioned(
                  top: 150,
                  right: 10,
                  child: GestureDetector(
                    onTap: () async {
                      await ZegoUIKitPrebuiltLiveStreamingController().pk
                          .quit()
                          .then(
                            (value) => setState(() {
                              isInPKBattle = false;
                            }),
                          );
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4757), Color(0xFFFF3838)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4757).withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.exit_to_app,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),

              //show Entrance Effect
              // showEntranceEffect ? entranceEffect() : Container(),
              _showTextField == true
                  ? Center(
                    child: Form(
                      key: formKey,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.95),
                              Colors.white.withOpacity(0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFF4ECDC4).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: TextFormField(
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Message Cannot be Empty";
                            }
                            return null;
                          },
                          style: const TextStyle(
                            color: Color(0xFF2D3436),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLength: 50,
                          maxLines: 1,
                          controller: platformTextEditingController,
                          decoration: InputDecoration(
                            counterStyle: const TextStyle(
                              color: Color(0xFF636E72),
                              fontSize: 12,
                            ),
                            errorStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF4757),
                              fontWeight: FontWeight.w500,
                            ),
                            suffixIcon: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4ECDC4),
                                    Color(0xFF44A08D),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4ECDC4,
                                    ).withOpacity(0.3),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () {
                                  if (formKey.currentState!.validate()) {
                                    _onSendPlatformMessage(
                                      platformTextEditingController.text,
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            fillColor: Colors.transparent,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            hintText: "Enter Platform Message",
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  : Container(),

              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: SlideTransition(
                    position: _offsetAnimation,
                    child: StreamBuilder(
                      // TODO: Implement platform message stream via backend
                      stream: Stream.periodic(const Duration(seconds: 5)),
                      builder: (context, AsyncSnapshot snapshot) {
                        // TODO: Implement platform message display
                        return Container();
                      },
                    ),
                  ),
                ),
              ),

              //button to send platform message
              if (widget.isHost)
                Positioned(
                  left: 0,
                  bottom: size.height / 2,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          print(
                            "Platform speaker number: $_platformSpeakerNumber",
                          );
                          if (_platformSpeakerNumber == 0) {
                            setState(() {
                              _showTextField = false;
                            });
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  backgroundColor: const Color(0xFF1A1A2E),
                                  title: const Text(
                                    'Cannot Send Message',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: const Text(
                                    'You are not allowed to send a platform message at this time.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF4ECDC4,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                            return;
                          }
                          setState(() {
                            _showTextField = !_showTextField;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _platformSpeakerNumber > 0
                                    ? const Color(0xFF4ECDC4).withOpacity(0.8)
                                    : Colors.grey.withOpacity(0.5),
                                _platformSpeakerNumber > 0
                                    ? const Color(0xFF44A08D).withOpacity(0.8)
                                    : Colors.grey.withOpacity(0.3),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow:
                                _platformSpeakerNumber > 0
                                    ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF4ECDC4,
                                        ).withOpacity(0.4),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Lottie.asset(
                            "assets/lotties/megaphone.json",
                            width: 36,
                            height: 36,
                          ),
                        ),
                      ),
                      if (_platformSpeakerNumber > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_platformSpeakerNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // void removeRequestingHostsMap(String requestID) {
  //   requestingHostsMapRequestIDNotifier.value.remove(requestID);

  //   requestingHostsMapRequestIDNotifier.notifyListeners();
  // }

  // void removeRequestingHostsMapWhenRemoteHostDone(
  //   String requestID,
  //   String fromHostID,
  // ) {
  //   requestingHostsMapRequestIDNotifier.value[requestID]
  //       ?.removeWhere((requestHostID) => fromHostID == requestHostID);
  //   if (requestingHostsMapRequestIDNotifier.value[requestID]?.isEmpty ??
  //       false) {
  //     removeRequestingHostsMap(requestID);
  //   }

  //   requestingHostsMapRequestIDNotifier.notifyListeners();
  // }

  void removeRequestingHostsMap(String requestID) {
    // Create a copy of the current map.
    final currentMap = Map<String, List<String>>.from(
      requestingHostsMapRequestIDNotifier.value,
    );
    // Remove the key.
    currentMap.remove(requestID);
    // Reassign to trigger listeners.
    requestingHostsMapRequestIDNotifier.value = currentMap;
  }

  void removeRequestingHostsMapWhenRemoteHostDone(
    String requestID,
    String fromHostID,
  ) {
    final currentMap = Map<String, List<String>>.from(
      requestingHostsMapRequestIDNotifier.value,
    );
    // Remove the host ID from the list for this requestID.
    final hostList = currentMap[requestID];
    if (hostList != null) {
      hostList.removeWhere((requestHostID) => requestHostID == fromHostID);
      if (hostList.isEmpty) {
        // Remove the key entirely if the list is empty.
        currentMap.remove(requestID);
      } else {
        // Otherwise, update the list.
        currentMap[requestID] = hostList;
      }
    }
    // Reassign to trigger listeners.
    requestingHostsMapRequestIDNotifier.value = currentMap;
  }

  Widget foregroundBuilder(context, size, ZegoUIKitUser? user, _) {
    if (user == null) {
      return Container();
    }

    final hostWidgets = [
      /// mute pk user
      // Positioned(
      //   top: 5,
      //   left: 5,
      //   child: SizedBox(
      //     width: 40,
      //     height: 40,
      //     child: PKMuteButton(userID: user.id),
      //   ),
      // ),
    ];

    return Stack(
      children: [
        ...((widget.isHost && user.id != widget.currentUser.id)
            ? hostWidgets
            : []),

        /// camera state
        // Positioned(
        //   top: 5,
        //   right: 35,
        //   child: SizedBox(
        //     width: 18,
        //     height: 18,
        //     child: CircleAvatar(
        //       backgroundColor: Colors.purple.withOpacity(0.6),
        //       child: Icon(
        //         user.camera.value ? Icons.videocam : Icons.videocam_off,
        //         color: Colors.white,
        //         size: 15,
        //       ),
        //     ),
        //   ),
        // ),

        /// microphone state
        // Positioned(
        //   top: 5,
        //   right: 5,
        //   child: SizedBox(
        //     width: 18,
        //     height: 18,
        //     child: CircleAvatar(
        //       backgroundColor: Colors.purple.withOpacity(0.6),
        //       child: Icon(
        //         user.microphone.value ? Icons.mic : Icons.mic_off,
        //         color: Colors.white,
        //         size: 15,
        //       ),
        //     ),
        //   ),
        // ),

        /// name
        // Positioned(
        //   top: 25,
        //   right: 5,
        //   child: Container(
        //     // width: 30,
        //     height: 18,
        //     color: Colors.purple,
        //     child: Text(user.name),
        //   ),
        // ),
      ],
    );
  }

  Widget giftForeground() {
    // TODO: Implement gift animation overlay
    return Container();
  }

  Widget _buildModernIconButton(IconData icon, {double size = 28}) {
    return Icon(icon, color: Colors.white, size: size);
  }

  Widget _buildAvatarPlaceholder(double size, String initial) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade600, Colors.blueGrey.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
        ),
      ),
    );
  }

  void openPKSettingSheet() async {
    showModalBottomSheet(
      context: (context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) {
        return _inviteToPK();
      },
    );
  }

  void handleQuitPKBattle({
    required BuildContext context,
    required ValueNotifier<Map<String, List<String>>>
    requestingHostsMapRequestIDNotifier,
  }) {
    if (!ZegoUIKitPrebuiltLiveStreamingController().pk.isInPK) {
      return;
    }

    ZegoUIKitPrebuiltLiveStreamingController().pk.quit().then((ret) {
      if (ret.error != null) {
        showDialog(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: const Text('quitPKBattle failed'),
              content: Text('Error: ${ret.error}'),
              actions: [
                CupertinoDialogAction(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        requestingHostsMapRequestIDNotifier.value = {};
      }
    });
  }

  Future<void> sendPKBattleRequest(
    BuildContext context,
    String anotherHostUserID,
  ) async {
    await ZegoUIKitPrebuiltLiveStreamingController().pk
        .sendRequest(
          timeout: 30, //todo
          targetHostIDs: [anotherHostUserID],
          // isAutoAccept: isAutoAcceptedNotifier.value,
        )
        .then((ret) {
          if (ret.error != null) {
            showDialog(
              context: context,
              builder: (context) {
                return CupertinoAlertDialog(
                  title: const Text('PK Battle Request failed'),
                  content: Text('Error: ${ret.error}'),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
            // } else {
            //   requestIDNotifier.value = ret.requestID;
            //   if (requestingHostsMapRequestIDNotifier.value
            //       .containsKey(ret.requestID)) {
            //     requestingHostsMapRequestIDNotifier.value[ret.requestID]!
            //         .add(anotherHostUserID);
            //   } else {
            //     requestingHostsMapRequestIDNotifier.value[ret.requestID] = [
            //       anotherHostUserID
            //     ];
            //   }
            //   requestingHostsMapRequestIDNotifier.notifyListeners();
            // }
          } else {
            requestIDNotifier.value = ret.requestID;

            // Create a copy of the current map.
            final currentMap = Map<String, List<String>>.from(
              requestingHostsMapRequestIDNotifier.value,
            );

            // Add the new host to the appropriate requestID key.
            if (currentMap.containsKey(ret.requestID)) {
              currentMap[ret.requestID]!.add(anotherHostUserID);
            } else {
              currentMap[ret.requestID] = [anotherHostUserID];
            }

            // Reassign the updated map to trigger listeners.
            requestingHostsMapRequestIDNotifier.value = currentMap;
          }
        });
  }

  List<dynamic>? invitedUserParty = [];
  List<dynamic>? invitedUserPartyListPending = [];
  List<dynamic>? invitedUserPartyListLivePending = [];
  UserModel? PKBattleRequestReceiver;

  Widget _inviteToPK() {
    int numberOfColumns = 3;
    // TODO: Fetch active live streams for PK invitation

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.1,
            maxChildSize: 1.0,
            builder: (_, controller) {
              return StatefulBuilder(
                builder: (context, setState) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0F0F23).withOpacity(0.95),
                          const Color(0xFF1A1A2E).withOpacity(0.95),
                          const Color(0xFF16213E).withOpacity(0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30.0),
                        topRight: Radius.circular(30.0),
                      ),
                      border: Border.all(
                        color: const Color(0xFF4ECDC4).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 25,
                          spreadRadius: 5,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Scaffold(
                      floatingActionButtonLocation:
                          FloatingActionButtonLocation.centerFloat,
                      floatingActionButtonAnimator:
                          FloatingActionButtonAnimator.scaling,
                      floatingActionButton: Visibility(
                        visible: invitedUserPartyListPending!.isNotEmpty,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B6B).withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 3,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                          child: FloatingActionButton(
                            onPressed: () async {
                              if (PKBattleRequestReceiver != null) {
                                // TODO: Get user ID from PKBattleRequestReceiver
                                // sendPKBattleRequest(context, userId);
                                Navigator.pop(context);
                              }
                            },
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  "assets/svg/ic_tab_live_selected.svg",
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                  width: 24,
                                  height: 24,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${invitedUserPartyListPending!.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      backgroundColor: Colors.transparent,
                      appBar: AppBar(
                        leading: Visibility(visible: false, child: Container()),
                        backgroundColor: Colors.transparent,
                        title: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 6,
                              margin: const EdgeInsets.only(
                                top: 12,
                                bottom: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4ECDC4),
                                    Color(0xFF44A08D),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4ECDC4,
                                    ).withOpacity(0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF4ECDC4).withOpacity(0.2),
                                    const Color(0xFF44A08D).withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF4ECDC4,
                                  ).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                "🎯 Invite To PK Battle",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        centerTitle: true,
                      ),
                      body: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TextWithTap(
                            //   "live_streaming.menu_for_you".tr(),
                            //   color: Colors.white,
                            //   fontSize: 16,
                            //   marginTop: 20,
                            //   marginLeft: 10,
                            //   marginBottom: 10,
                            // ),
                            Expanded(
                              flex: 2,
                              child: FutureBuilder<List<LiveStreamModel>>(
                                future:
                                    LiveStreamingService.getValidatedActiveLiveStreams(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snapshot.hasError ||
                                      !snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'No active live streams',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    );
                                  }

                                  return GridView.builder(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: numberOfColumns,
                                          crossAxisSpacing: 2,
                                          mainAxisSpacing: 2,
                                          childAspectRatio: 1.0,
                                        ),
                                    itemCount: snapshot.data!.length,
                                    itemBuilder: (context, index) {
                                      LiveStreamModel liveStreaming =
                                          snapshot.data![index];

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (invitedUserPartyListPending!
                                                .contains(
                                                  liveStreaming.authorUid
                                                      .toString(),
                                                )) {
                                              invitedUserPartyListPending!
                                                  .remove(
                                                    liveStreaming.authorUid
                                                        .toString(),
                                                  );
                                              invitedUserPartyListLivePending!
                                                  .remove(liveStreaming);
                                            } else {
                                              if (invitedUserPartyListPending!
                                                          .length +
                                                      invitedUserParty!.length >
                                                  1) {
                                                ToasterService.showError(
                                                  context,
                                                  "You can only invite 1 host to PK battle",
                                                );
                                                return;
                                              }

                                              invitedUserPartyListPending!.add(
                                                liveStreaming.authorUid
                                                    .toString(),
                                              );
                                              invitedUserPartyListLivePending!
                                                  .add(liveStreaming);

                                              if (liveStreaming.author !=
                                                  null) {
                                                // PKBattleRequestReceiver = liveStreaming.author!;
                                              }
                                            }
                                          });
                                        },
                                        child: Stack(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Stack(
                                                  children: [
                                                    Image.network(
                                                      liveStreaming.image ?? '',
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => Container(
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                colors: [
                                                                  Colors
                                                                      .grey[800]!,
                                                                  Colors
                                                                      .grey[600]!,
                                                                ],
                                                                begin:
                                                                    Alignment
                                                                        .topLeft,
                                                                end:
                                                                    Alignment
                                                                        .bottomRight,
                                                              ),
                                                            ),
                                                            child: const Icon(
                                                              Icons
                                                                  .image_not_supported,
                                                              color:
                                                                  Colors
                                                                      .white54,
                                                              size: 40,
                                                            ),
                                                          ),
                                                    ),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            Colors.black
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                            Colors.black
                                                                .withOpacity(
                                                                  0.4,
                                                                ),
                                                          ],
                                                          begin:
                                                              Alignment
                                                                  .topCenter,
                                                          end:
                                                              Alignment
                                                                  .bottomCenter,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 0,
                                              child: Container(
                                                height: 45,
                                                width:
                                                    (MediaQuery.of(
                                                          context,
                                                        ).size.width /
                                                        numberOfColumns),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(12),
                                                        topRight:
                                                            Radius.circular(12),
                                                      ),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.black.withOpacity(
                                                        0.8,
                                                      ),
                                                      Colors.black.withOpacity(
                                                        0.4,
                                                      ),
                                                      Colors.transparent,
                                                    ],
                                                  ),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.1),
                                                    width: 0.5,
                                                  ),
                                                ),
                                                padding: const EdgeInsets.only(
                                                  left: 10,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.people,
                                                          color: Colors.white,
                                                          size: 12,
                                                        ),
                                                        Text(
                                                          '${liveStreaming.viewersCount}',
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 10,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        const Icon(
                                                          Icons.diamond,
                                                          color: Colors.cyan,
                                                          size: 14,
                                                        ),
                                                        Text(
                                                          '${liveStreaming.author?.diamonds ?? 0}',
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 10,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        gradient:
                                                            invitedUserPartyListPending!.contains(
                                                                  liveStreaming
                                                                      .authorUid
                                                                      .toString(),
                                                                )
                                                                ? const LinearGradient(
                                                                  colors: [
                                                                    Color(
                                                                      0xFF4ECDC4,
                                                                    ),
                                                                    Color(
                                                                      0xFF44A08D,
                                                                    ),
                                                                  ],
                                                                )
                                                                : LinearGradient(
                                                                  colors: [
                                                                    Colors.white
                                                                        .withOpacity(
                                                                          0.2,
                                                                        ),
                                                                    Colors.white
                                                                        .withOpacity(
                                                                          0.1,
                                                                        ),
                                                                  ],
                                                                ),
                                                        border: Border.all(
                                                          color:
                                                              invitedUserPartyListPending!.contains(
                                                                    liveStreaming
                                                                        .authorUid
                                                                        .toString(),
                                                                  )
                                                                  ? Colors.white
                                                                      .withOpacity(
                                                                        0.3,
                                                                      )
                                                                  : Colors.white
                                                                      .withOpacity(
                                                                        0.1,
                                                                      ),
                                                          width: 1,
                                                        ),
                                                        boxShadow:
                                                            invitedUserPartyListPending!.contains(
                                                                  liveStreaming
                                                                      .authorUid
                                                                      .toString(),
                                                                )
                                                                ? [
                                                                  BoxShadow(
                                                                    color: const Color(
                                                                      0xFF4ECDC4,
                                                                    ).withOpacity(
                                                                      0.4,
                                                                    ),
                                                                    blurRadius:
                                                                        6,
                                                                    spreadRadius:
                                                                        1,
                                                                  ),
                                                                ]
                                                                : null,
                                                      ),
                                                      child: Icon(
                                                        invitedUserPartyListPending!
                                                                .contains(
                                                                  liveStreaming
                                                                      .authorUid
                                                                      .toString(),
                                                                )
                                                            ? Icons.check_circle
                                                            : Icons
                                                                .radio_button_unchecked,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (liveStreaming.private)
                                              const Center(
                                                child: Icon(
                                                  Icons.vpn_key,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            Positioned(
                                              bottom: 0,
                                              child: Container(
                                                width:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.width /
                                                    numberOfColumns,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.black.withOpacity(
                                                        0.6,
                                                      ),
                                                      Colors.black.withOpacity(
                                                        0.3,
                                                      ),
                                                      Colors.transparent,
                                                    ],
                                                    begin:
                                                        Alignment.bottomCenter,
                                                    end: Alignment.topCenter,
                                                  ),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                        bottomLeft:
                                                            Radius.circular(12),
                                                        bottomRight:
                                                            Radius.circular(12),
                                                      ),
                                                ),
                                                child: Text(
                                                  liveStreaming
                                                          .author
                                                          ?.displayName ??
                                                      'Host',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    shadows: [
                                                      Shadow(
                                                        blurRadius: 2,
                                                        color: Colors.black,
                                                        offset: Offset(0, 1),
                                                      ),
                                                    ],
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // BUTTON DEFINITIONS
  // ============================================================================

  void showGiftBottomSheet({
    required BuildContext context,
    required TokenUser currentUser,
    required dynamic hostUser,
    required LiveStreamModel liveStream,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => GiftBottomSheet(
            liveStreamId: liveStream.id,
            onGiftSent: (gift) {
              // TODO: Implement actual gift sending logic via service
              print('Gift sent: ${gift.name}');
              ToasterService.showSuccess(context, 'Sent ${gift.name}!');
            },
          ),
    );
  }

  /// Gift button for viewers to send gifts
  // ZegoLiveStreamingMenuBarExtendButton get giftButton =>
  //     ZegoLiveStreamingMenuBarExtendButton(
  //   child: GestureDetector(
  //     onTap: () {
  //       showGiftBottomSheet(
  //         context: context,
  //         currentUser: widget.currentUser,
  //         hostUser: widget.mUser ?? widget.currentUser,
  //         liveStream: widget.mLiveStreamingModel,
  //       );
  //     },
  //     child: Icon(Icons.card_giftcard, color: Colors.white, size: 24),
  //   ),
  // );

  /// Share button to share live stream link
  // ZegoLiveStreamingMenuBarExtendButton get shareButton =>
  //     ZegoLiveStreamingMenuBarExtendButton(
  //   child: GestureDetector(
  //     onTap: () {
  //       createLink(widget.mLiveStreamingModel.id);
  //     },
  //     child: Icon(Icons.share, color: Colors.white, size: 24),
  //   ),
  // );

  /// Translate button to toggle message translation
  // ZegoLiveStreamingMenuBarExtendButton get translateButton =>
  //     ZegoLiveStreamingMenuBarExtendButton(
  //       child: GestureDetector(
  //         onTap: () {
  //           setState(() {
  //             translate = !translate;
  //           });
  //           if (translate) {
  //             ToasterService.showSuccess(
  //               context,
  //               "Messages are being translated",
  //             );
  //           }
  //         },
  //         child: Icon(Icons.translate, color: Colors.white, size: 24),
  //       ),
  //     );

  /// Like button for host to show appreciation
  // ZegoLiveStreamingMenuBarExtendButton get likeButton =>
  //     ZegoLiveStreamingMenuBarExtendButton(
  //       child: IconButton(
  //         icon: Icon(
  //           Icons.favorite_border_outlined,
  //           color: const Color(0xFFFF4D67),
  //         ),
  //         onPressed: () {
  //           // TODO: Implement like animation if needed
  //           ToasterService.showSuccess(context, "❤️");
  //         },
  //         padding: EdgeInsets.zero,
  //         constraints: BoxConstraints(),
  //       ),
  //     );
}
