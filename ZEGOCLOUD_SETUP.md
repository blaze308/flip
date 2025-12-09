# ZegoCloud Setup Guide for Flip

This guide will help you configure ZegoCloud for video and audio calls in the Flip app.

## Why ZegoCloud?

We migrated from Jitsi to ZegoCloud because:
- ✅ **Native Flutter implementation** - No React Native dependencies!
- ✅ **Better performance** - Optimized for mobile
- ✅ **Easier integration** - Prebuilt UI components
- ✅ **More reliable** - Professional-grade infrastructure
- ✅ **Better documentation** - Comprehensive Flutter support

## Step 1: Create ZegoCloud Account

1. Go to [https://console.zegocloud.com/](https://console.zegocloud.com/)
2. Sign up for a free account
3. Create a new project

## Step 2: Get Your Credentials

1. In the ZegoCloud console, go to your project
2. Navigate to **Project Management** → **Project Information**
3. Copy your:
   - **AppID** (a number, e.g., `1234567890`)
   - **AppSign** (a long string, e.g., `"abc123def456..."`)

## Step 3: Add Credentials to Your App

Open `flip/lib/services/zego_call_service.dart` and replace the placeholder values:

```dart
// TODO: Replace with your actual ZegoCloud credentials
static const int appID = 1234567890; // Replace with your App ID
static const String appSign = 'your_app_sign_here'; // Replace with your App Sign
```

**Example:**
```dart
static const int appID = 1234567890;
static const String appSign = 'abc123def456ghi789jkl012mno345pqr678stu901vwx234yz';
```

## Step 4: Install Dependencies

Run the following command to install ZegoCloud packages:

```bash
cd flip
flutter pub get
```

## Step 5: Build and Test

### For Android:
```bash
flutter build apk --debug
flutter install
```

### For iOS:
```bash
cd ios
pod install
cd ..
flutter build ios
```

## Features

### Video Calls
- One-on-one video calls
- Camera switching (front/back)
- Video mute/unmute
- Picture-in-picture support

### Audio Calls
- One-on-one audio calls
- Microphone mute/unmute
- Speaker/earpiece switching
- Audio waveform visualization

## Customization

You can customize the call UI in `flip/lib/services/zego_call_service.dart`:

### Change Button Layout
```dart
..bottomMenuBar = ZegoCallBottomMenuBarConfig(
  buttons: [
    ZegoCallMenuBarButtonName.toggleCameraButton,
    ZegoCallMenuBarButtonName.switchCameraButton,
    ZegoCallMenuBarButtonName.hangUpButton,
    ZegoCallMenuBarButtonName.toggleMicrophoneButton,
    ZegoCallMenuBarButtonName.switchAudioOutputButton,
  ],
)
```

### Modify Call Behavior
```dart
..onOnlySelfInRoom = (context) {
  // Custom behavior when other user leaves
  Navigator.of(context).pop();
}
..onHangUp = () {
  // Custom behavior when user hangs up
  Navigator.of(context).pop();
}
```

## Pricing

ZegoCloud offers:
- **Free Tier**: 10,000 minutes/month
- **Pay-as-you-go**: After free tier
- **Enterprise**: Custom pricing

Check [ZegoCloud Pricing](https://www.zegocloud.com/pricing) for details.

## Troubleshooting

### Issue: "AppID is 0" Error
**Solution**: Make sure you've replaced the placeholder `appID` and `appSign` in `zego_call_service.dart`

### Issue: Camera/Microphone Not Working
**Solution**: Check that permissions are granted in:
- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/Info.plist`

### Issue: Call Not Connecting
**Solution**: 
1. Verify your AppID and AppSign are correct
2. Check your internet connection
3. Ensure both users are using the same CallID

## Support

- [ZegoCloud Documentation](https://docs.zegocloud.com/article/13810)
- [Flutter SDK Reference](https://pub.dev/packages/zego_uikit_prebuilt_call)
- [ZegoCloud Support](https://www.zegocloud.com/support)

## Migration Notes

### Removed Files
- ❌ `lib/services/jitsi_call_service.dart`
- ❌ `lib/services/jitsi_service.dart`
- ❌ `lib/screens/jitsi_call_screen.dart`
- ❌ `jitsi-meet-flutter-sdk/` (entire directory)

### New Files
- ✅ `lib/services/zego_call_service.dart`
- ✅ `lib/screens/zego_call_screen.dart`

### Updated Files
- ✅ `lib/screens/chat_screen.dart` - Now uses ZegoCallScreen
- ✅ `lib/screens/incoming_call_screen.dart` - Now uses ZegoCallScreen
- ✅ `pubspec.yaml` - Replaced Jitsi with ZegoCloud packages
- ✅ `android/app/build.gradle.kts` - Removed Jitsi configurations
- ✅ `android/app/src/main/AndroidManifest.xml` - Updated permissions

---

**Ready to test?** Just add your credentials and run the app! 🚀

