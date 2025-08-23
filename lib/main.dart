import 'package:flutter/material.dart';
import 'splash_screen.dart';
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

void main() {
  runApp(const AncientFlipApp());
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
        '/': (context) => const SplashScreen(),
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
      },
    );
  }
}
