// import 'dart:convert';
// import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
// import 'package:http/http.dart' as http;
// import 'token_auth_service.dart';

// class JitsiService {
//   static const String baseUrl = 'https://flip-backend-mnpg.onrender.com';
//   static const Duration timeoutDuration = Duration(seconds: 30);

//   static JitsiMeet? _jitsiMeet;
//   static bool _isInCall = false;

//   /// Initialize Jitsi Meet
//   static Future<void> initialize() async {
//     try {
//       _jitsiMeet = JitsiMeet();
//       print('📞 JitsiService: Initialized successfully');
//     } catch (e) {
//       print('📞 JitsiService: Error initializing: $e');
//     }
//   }

//   /// Create a call room and send invitation
//   static Future<CallResult> createCall({
//     required String chatId,
//     required List<String> participants,
//     required CallType type,
//   }) async {
//     try {
//       print('📞 JitsiService: Creating ${type.name} call for chat $chatId');

//       final headers = await TokenAuthService.getAuthHeaders();
//       if (headers == null) {
//         return CallResult(success: false, message: 'Authentication required');
//       }

//       final uri = Uri.parse('$baseUrl/api/calls/create');
//       final body = {
//         'chatId': chatId,
//         'participants': participants,
//         'type': type.name,
//       };

//       final response = await http
//           .post(uri, headers: headers, body: json.encode(body))
//           .timeout(timeoutDuration);

//       print('📞 JitsiService: Response status: ${response.statusCode}');

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final data = json.decode(response.body) as Map<String, dynamic>;
//         final callData = data['data'] as Map<String, dynamic>;

//         return CallResult(
//           success: true,
//           message: data['message'] as String? ?? 'Call created successfully',
//           roomId: callData['roomId'] as String?,
//           callId: callData['callId'] as String?,
//         );
//       } else {
//         final errorData = json.decode(response.body) as Map<String, dynamic>;
//         throw Exception(errorData['message'] ?? 'Failed to create call');
//       }
//     } catch (e) {
//       print('📞 JitsiService: Error creating call: $e');
//       return CallResult(
//         success: false,
//         message: 'Failed to create call: ${e.toString()}',
//       );
//     }
//   }

//   /// Join a Jitsi Meet call
//   static Future<bool> joinCall({
//     required String roomId,
//     required String displayName,
//     CallType type = CallType.video,
//     String? avatar,
//   }) async {
//     try {
//       if (_jitsiMeet == null) {
//         await initialize();
//       }

//       if (_isInCall) {
//         print('📞 JitsiService: Already in a call');
//         return false;
//       }

//       print('📞 JitsiService: Joining call room: $roomId');

//       // Configure Jitsi Meet options
//       final options = JitsiMeetConferenceOptions(
//         serverURL: "https://meet.jit.si", // You can use your own Jitsi server
//         room: roomId,
//         configOverrides: {
//           "startWithAudioMuted": false,
//           "startWithVideoMuted": type == CallType.audio,
//           "subject": "Flip Call",
//         },
//         featureFlags: {
//           "unsaferoomwarning.enabled": false,
//           "prejoinpage.enabled": false,
//         },
//         userInfo: JitsiMeetUserInfo(
//           displayName: displayName,
//           email: "", // Optional
//           avatar: avatar,
//         ),
//       );

//       // Join the call
//       await _jitsiMeet!.join(options);
//       _isInCall = true;

//       print('📞 JitsiService: Successfully joined call');
//       return true;
//     } catch (e) {
//       print('📞 JitsiService: Error joining call: $e');
//       return false;
//     }
//   }

//   /// Leave the current call
//   static Future<void> leaveCall() async {
//     try {
//       if (_jitsiMeet != null && _isInCall) {
//         await _jitsiMeet!.hangUp();
//         _isInCall = false;
//         print('📞 JitsiService: Left call successfully');
//       }
//     } catch (e) {
//       print('📞 JitsiService: Error leaving call: $e');
//     }
//   }

//   /// End a call and notify participants
//   static Future<bool> endCall(String callId) async {
//     try {
//       print('📞 JitsiService: Ending call $callId');

//       final headers = await TokenAuthService.getAuthHeaders();
//       if (headers == null) {
//         return false;
//       }

//       final uri = Uri.parse('$baseUrl/api/calls/$callId/end');
//       final response = await http
//           .post(uri, headers: headers)
//           .timeout(timeoutDuration);

//       if (response.statusCode == 200) {
//         await leaveCall();
//         print('📞 JitsiService: Call ended successfully');
//         return true;
//       } else {
//         print('📞 JitsiService: Failed to end call: ${response.statusCode}');
//         return false;
//       }
//     } catch (e) {
//       print('📞 JitsiService: Error ending call: $e');
//       return false;
//     }
//   }

//   /// Check if currently in a call
//   static bool get isInCall => _isInCall;

//   /// Generate a unique room ID
//   static String generateRoomId() {
//     final timestamp = DateTime.now().millisecondsSinceEpoch;
//     final random = (timestamp % 10000).toString().padLeft(4, '0');
//     return 'flip-call-$timestamp-$random';
//   }

//   /// Dispose resources
//   static Future<void> dispose() async {
//     try {
//       if (_isInCall) {
//         await leaveCall();
//       }
//       _jitsiMeet = null;
//       print('📞 JitsiService: Resources disposed');
//     } catch (e) {
//       print('📞 JitsiService: Error disposing resources: $e');
//     }
//   }
// }

// /// Call types
// enum CallType { audio, video }

// /// Call result model
// class CallResult {
//   final bool success;
//   final String message;
//   final String? roomId;
//   final String? callId;

//   const CallResult({
//     required this.success,
//     required this.message,
//     this.roomId,
//     this.callId,
//   });
// }

// /// Call invitation model
// class CallInvitation {
//   final String callId;
//   final String roomId;
//   final String chatId;
//   final String callerId;
//   final String callerName;
//   final CallType type;
//   final List<String> participants;
//   final DateTime createdAt;

//   const CallInvitation({
//     required this.callId,
//     required this.roomId,
//     required this.chatId,
//     required this.callerId,
//     required this.callerName,
//     required this.type,
//     required this.participants,
//     required this.createdAt,
//   });

//   factory CallInvitation.fromJson(Map<String, dynamic> json) {
//     return CallInvitation(
//       callId: json['callId'] as String,
//       roomId: json['roomId'] as String,
//       chatId: json['chatId'] as String,
//       callerId: json['callerId'] as String,
//       callerName: json['callerName'] as String,
//       type: CallType.values.firstWhere(
//         (e) => e.name == json['type'],
//         orElse: () => CallType.video,
//       ),
//       participants:
//           (json['participants'] as List<dynamic>)
//               .map((p) => p as String)
//               .toList(),
//       createdAt: DateTime.parse(json['createdAt'] as String),
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'callId': callId,
//       'roomId': roomId,
//       'chatId': chatId,
//       'callerId': callerId,
//       'callerName': callerName,
//       'type': type.name,
//       'participants': participants,
//       'createdAt': createdAt.toIso8601String(),
//     };
//   }
// }
