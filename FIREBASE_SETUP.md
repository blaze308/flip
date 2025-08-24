# Firebase Setup Guide

This guide will help you set up Firebase authentication for your Flutter app.

## ✅ ALREADY COMPLETED (Done Automatically)

The following configurations have been automatically implemented:

- ✅ Flutter dependencies added to `pubspec.yaml`
- ✅ Firebase initialization in `main.dart`
- ✅ Complete Firebase Auth service implementation
- ✅ Android Gradle configuration updated
- ✅ iOS Info.plist prepared for Firebase
- ✅ All authentication screens updated to use Firebase

## 🔴 MANUAL STEPS REQUIRED (You Need to Do These)

### Step 1: Create Firebase Project

**⚠️ REQUIRED - You must do this manually**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter your project name (e.g., "AncientFlip")
4. Enable Google Analytics (optional but recommended)
5. Click "Create project"

### Step 2: Enable Authentication Methods

**⚠️ REQUIRED - You must do this manually**

1. In your Firebase project, go to **Authentication** > **Sign-in method**
2. Enable the following providers:
   - **Email/Password**: Click and toggle "Enable"
   - **Phone**: Click and toggle "Enable"
   - **Google**: Click, toggle "Enable", and configure OAuth consent screen
   - **Apple**: Click, toggle "Enable" (iOS only)

### Step 3: Add Android App & Download Config

**⚠️ REQUIRED - You must do this manually**

1. In Firebase Console, click "Add app" and select Android
2. Enter your Android package name: `ancientplustech.ancient.flipflip`
3. **IMPORTANT**: Download the `google-services.json` file
4. **IMPORTANT**: Place it in `flip/android/app/` directory (next to build.gradle.kts)
5. The SHA-1 fingerprint is optional for development

**File Location**: The `google-services.json` must be placed at:

```
flip/
├── android/
│   ├── app/
│   │   ├── google-services.json  ← PUT IT HERE
│   │   └── build.gradle.kts
```

### Step 4: Add iOS App & Download Config

**⚠️ REQUIRED - You must do this manually**

1. In Firebase Console, click "Add app" and select iOS
2. Enter your iOS bundle ID: `ancientplustech.ancient.flipflip`
3. **IMPORTANT**: Download the `GoogleService-Info.plist` file
4. **IMPORTANT**: Open `flip/ios/Runner.xcworkspace` in Xcode
5. **IMPORTANT**: Drag `GoogleService-Info.plist` into the Runner folder in Xcode
6. Make sure "Add to target" is checked for Runner

### Step 5: Update iOS URL Scheme

**⚠️ REQUIRED - You must do this manually**

1. Open the `GoogleService-Info.plist` file you downloaded
2. Find the `REVERSED_CLIENT_ID` value (looks like: `com.googleusercontent.apps.123456789-abc...`)
3. Open `flip/ios/Runner/Info.plist`
4. Replace `YOUR_REVERSED_CLIENT_ID_HERE` with your actual `REVERSED_CLIENT_ID`

**Example**:

```xml
<!-- Replace this line -->
<string>YOUR_REVERSED_CLIENT_ID_HERE</string>
<!-- With something like -->
<string>com.googleusercontent.apps.123456789-abcdefghijklmnop.apps.googleusercontent.com</string>
```

## ✅ AUTOMATIC CONFIGURATIONS (Already Done)

### Android Configuration ✅

The following have been automatically configured in your Gradle files:

- Google Services plugin added: `id("com.google.gms.google-services")`
- Google Services classpath added to project build.gradle.kts
- MultiDex enabled: `multiDexEnabled = true`
- Minimum SDK set to 21 (required for Firebase)
- MultiDex dependency added: `androidx.multidex:multidex:2.0.1`

### iOS Configuration ✅

The following have been automatically configured:

- Info.plist prepared with URL scheme structure for Google Sign-In
- Ready for GoogleService-Info.plist integration

## 🧪 Testing Your Setup

After completing the manual steps above:

1. **Clean and rebuild**:

   ```bash
   cd flip
   flutter clean
   flutter pub get
   ```

2. **Test on physical devices** (required for phone auth):

   ```bash
   flutter run
   ```

3. **Test each authentication method**:
   - ✅ Email/Password registration and login
   - ✅ Google Sign-In (after config files added)
   - ✅ Apple Sign-In (iOS only, after config files added)
   - ✅ Phone number verification (physical device only)
   - ✅ Password reset via email

## 🔧 Additional Setup for Production

### Get SHA-1 Fingerprint (Android)

For production releases, you'll need to add your SHA-1 fingerprint:

```bash
# For debug (development)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# For release (production)
keytool -list -v -keystore /path/to/your/release.keystore -alias your-alias
```

Add the SHA-1 fingerprint to Firebase Console > Project Settings > Your Android App.

### Apple Sign-In Setup (iOS Production)

1. In Xcode, go to your project settings
2. Select your target > Signing & Capabilities
3. Add "Sign in with Apple" capability
4. In Apple Developer Console, enable Sign in with Apple for your App ID

## 🚨 Troubleshooting

### Common Issues:

1. **"google-services.json not found"**:

   - Ensure the file is in `flip/android/app/google-services.json`
   - Run `flutter clean && flutter pub get`

2. **"GoogleService-Info.plist not found"**:

   - Open `flip/ios/Runner.xcworkspace` in Xcode
   - Drag the plist file into the Runner folder
   - Ensure "Add to target" is checked

3. **Google Sign-In not working**:

   - Check that package name matches exactly: `ancientplustech.ancient.flipflip`
   - Verify SHA-1 fingerprint is added (for production)
   - Ensure `REVERSED_CLIENT_ID` is correctly set in Info.plist

4. **Phone authentication not working**:

   - Test on physical device (not simulator)
   - Ensure proper internet connection
   - Check Firebase Console for quota limits

5. **Apple Sign-In not working**:
   - Test on physical iOS device only
   - Ensure Sign in with Apple capability is added in Xcode
   - Verify bundle ID matches in Firebase and Apple Developer Console

## 🎯 Account Linking Behavior

The app automatically handles account linking:

- If user signs up with email and later tries Google/Apple with same email
- System prompts them to use original sign-in method first
- Prevents duplicate accounts for same email address

## 📱 Ready for Backend Integration

Once Firebase is configured, user data will be available for your backend:

```dart
// Firebase user data structure
{
  "uid": "firebase_user_id",
  "email": "user@example.com",
  "displayName": "User Name",
  "phoneNumber": "+1234567890",
  "emailVerified": true,
  "photoURL": "https://...",
  "createdAt": "2024-01-01T00:00:00Z",
  "lastLogin": "2024-01-01T00:00:00Z"
}
```

## 🎉 Next Steps

After completing the manual setup:

1. Test all authentication methods
2. Set up your backend to receive Firebase user data
3. Configure Firestore security rules (if using Firestore)
4. Add Firebase Analytics and Crashlytics
5. Deploy to production with proper signing certificates

---

**Need Help?** Check the Firebase Console error logs and device logs for detailed error messages.
