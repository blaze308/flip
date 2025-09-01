import 'package:flutter/material.dart';
import 'services/token_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test widget to verify onboarding flow works correctly
class TestOnboardingFlow extends StatefulWidget {
  const TestOnboardingFlow({super.key});

  @override
  State<TestOnboardingFlow> createState() => _TestOnboardingFlowState();
}

class _TestOnboardingFlowState extends State<TestOnboardingFlow> {
  bool? _isFirstLaunch;
  bool? _hasCompletedOnboarding;
  AuthState _currentState = AuthState.initial;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
    TokenAuthService.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    TokenAuthService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged(AuthState state, TokenUser? user) {
    if (mounted) {
      setState(() {
        _currentState = state;
      });
    }
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFirstLaunch = prefs.getBool('first_launch') ?? true;
      _hasCompletedOnboarding = prefs.getBool('onboarding_completed') ?? false;
    });
  }

  Future<void> _resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('first_launch', true),
      prefs.setBool('onboarding_completed', false),
    ]);
    await _checkOnboardingStatus();

    // Reinitialize auth service to trigger onboarding
    await TokenAuthService.initialize();
  }

  Future<void> _completeOnboarding() async {
    await TokenAuthService.completeOnboarding();
    await _checkOnboardingStatus();
  }

  Future<void> _skipToHome() async {
    await TokenAuthService.skipToHome();
    await _checkOnboardingStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding Flow Test'),
        backgroundColor: const Color(0xFF4ECDC4),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Onboarding Status',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'First Launch: ${_isFirstLaunch ?? "Loading..."}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Onboarding Completed: ${_hasCompletedOnboarding ?? "Loading..."}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Auth State: ${_currentState.name}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Should Show Onboarding: ${(_isFirstLaunch == true && _hasCompletedOnboarding == false)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Test Actions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetOnboarding,
              child: const Text('Reset Onboarding (Simulate First Launch)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _completeOnboarding,
              child: const Text('Complete Onboarding'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _skipToHome,
              child: const Text('Skip to Home (Guest Mode)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkOnboardingStatus,
              child: const Text('Refresh Status'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Expected Behavior:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('✅ Onboarding shows only on first launch'),
            const Text('✅ Skip buttons complete onboarding and go to home'),
            const Text('✅ Get Started button completes onboarding'),
            const Text('✅ Users can access home without authentication'),
            const Text('✅ Onboarding state persists across app restarts'),
          ],
        ),
      ),
    );
  }
}
