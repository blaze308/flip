import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ZegoCallService {
  static final ZegoCallService _instance = ZegoCallService._internal();
  factory ZegoCallService() => _instance;
  ZegoCallService._internal();

  static int appID = int.tryParse(dotenv.env['ZEGO_APP_ID'] ?? '') ?? 0;
  static String appSign = dotenv.env['ZEGO_APP_SIGN'] ?? '';

  /// Navigate to video call screen
  static Future<void> startVideoCall({
    required BuildContext context,
    required String callID,
    required String userID,
    required String userName,
    required String recipientName,
  }) async {
    try {
      print('📞 ZegoCallService: Starting video call - $callID');

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ZegoUIKitPrebuiltCall(
                appID: appID,
                appSign: appSign,
                userID: userID,
                userName: userName,
                callID: callID,
                config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
              ),
        ),
      );

      print('✅ ZegoCallService: Video call ended');
    } catch (e) {
      print('❌ ZegoCallService: Error starting video call: $e');
      rethrow;
    }
  }

  /// Navigate to audio call screen
  static Future<void> startAudioCall({
    required BuildContext context,
    required String callID,
    required String userID,
    required String userName,
    required String recipientName,
  }) async {
    try {
      print('📞 ZegoCallService: Starting audio call - $callID');

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ZegoUIKitPrebuiltCall(
                appID: appID,
                appSign: appSign,
                userID: userID,
                userName: userName,
                callID: callID,
                config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
              ),
        ),
      );

      print('✅ ZegoCallService: Audio call ended');
    } catch (e) {
      print('❌ ZegoCallService: Error starting audio call: $e');
      rethrow;
    }
  }

  /// Generate unique call ID for Flip calls
  static String generateCallID(String chatId, String timestamp) {
    return 'flip_${chatId}_$timestamp';
  }

  /// Dispose resources (if needed)
  void dispose() {
    print('📞 ZegoCallService: Resources disposed');
  }
}
