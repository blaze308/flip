import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'onboarding_screen.dart';
import 'onboarding_screen_two.dart';
import 'onboarding_screen_three.dart';
import 'register_screen.dart';
import 'login_screen.dart';
import 'forget_password_screen.dart';
import 'reset_verification_screen.dart';
import 'new_password_screen.dart';
import 'phone_registration_screen.dart';
import 'otp_verification_screen.dart';
import 'home_screen.dart';
import 'biometric_setup_screen.dart';
import 'biometric_login_screen.dart';
import 'complete_profile_screen.dart';
import 'token_app_router.dart';
import 'create_story_type_screen.dart';
import 'create_text_story_screen.dart';
import 'create_image_story_screen.dart';
import 'create_video_story_screen.dart';
import 'create_audio_story_screen.dart';
import 'screens/message_list_screen.dart';
import 'services/app_lifecycle_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Lifecycle Manager for background handling
  await AppLifecycleManager.instance.initialize();

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
