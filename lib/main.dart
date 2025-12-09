import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/onboarding_screen_two.dart';
import 'screens/onboarding/onboarding_screen_three.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/forget_password_screen.dart';
import 'screens/auth/reset_verification_screen.dart';
import 'screens/auth/new_password_screen.dart';
import 'screens/auth/phone_registration_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/biometric_setup_screen.dart';
import 'screens/auth/biometric_login_screen.dart';
import 'screens/auth/complete_profile_screen.dart';
import 'token_app_router.dart';
import 'screens/create/create_story_type_screen.dart';
import 'screens/create/create_text_story_screen.dart';
import 'screens/create/create_image_story_screen.dart';
import 'screens/create/create_video_story_screen.dart';
import 'screens/create/create_audio_story_screen.dart';
import 'screens/chat/message_list_screen.dart';
import 'services/app_lifecycle_manager.dart';
import 'services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('⚠️ Warning: Could not load .env file: $e');
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Lifecycle Manager for background handling
  await AppLifecycleManager.instance.initialize();

  // Initialize Connectivity Service
  await ConnectivityService().initialize();

  runApp(const ProviderScope(child: AncientFlipApp()));
}

class AncientFlipApp extends StatelessWidget {
  const AncientFlipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AncientFlip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4ECDC4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const TokenAppRouter(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/onboarding2': (context) => const OnboardingScreenTwo(),
        '/onboarding3': (context) => const OnboardingScreenThree(),
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/forget-password': (context) => const ForgetPasswordScreen(),
        '/reset-verification': (context) => const ResetVerificationScreen(),
        '/new-password': (context) => const NewPasswordScreen(),
        '/phone-registration': (context) => const PhoneRegistrationScreen(),
        '/otp-verification': (context) => const OtpVerificationScreen(),
        '/home': (context) => const HomeScreen(),
        '/biometric-setup': (context) => const BiometricSetupScreen(),
        '/biometric-login': (context) => const BiometricLoginScreen(),
        '/complete-profile': (context) => const CompleteProfileScreen(),
        '/create-story': (context) => const CreateStoryTypeScreen(),
        '/create-text-story': (context) => const CreateTextStoryScreen(),
        '/create-image-story': (context) => const CreateImageStoryScreen(),
        '/create-video-story': (context) => const CreateVideoStoryScreen(),
        '/create-audio-story': (context) => const CreateAudioStoryScreen(),
        '/messages': (context) => const MessageListScreen(),
      },
    );
  }
}
