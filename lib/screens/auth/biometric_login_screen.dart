import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/message_service.dart';
import '../../widgets/custom_toaster.dart';
import '../../services/storage_service.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isAvailable = false;
  List<BiometricType> _availableTypes = [];
  String _statusMessage = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkBiometricStatus();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricStatus() async {
    final isEnabled = await BiometricAuthService.isBiometricEnabled();
    if (!isEnabled) {
      // If biometric is not enabled, redirect to regular login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    final availability =
        await BiometricAuthService.checkBiometricAvailability();

    setState(() {
      _isAvailable = availability.isAvailable;
      _availableTypes = availability.availableTypes;
      _statusMessage = availability.message;
    });

    if (_isAvailable) {
      // Auto-trigger biometric authentication
      _authenticateWithBiometric();
    }
  }

  Future<void> _authenticateWithBiometric() async {
    setState(() {
      _isLoading = true;
    });

    final result = await BiometricAuthService.quickLogin();

    if (result.success) {
      // Biometric authentication successful
      // Check if user is still logged in with Firebase
      final isLoggedIn = await StorageService.isLoggedIn();
      final hasValidToken = await StorageService.hasValidToken();

      if (isLoggedIn && hasValidToken) {
        // User is already authenticated, navigate to home
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // Need to re-authenticate with Firebase
        // For now, redirect to login screen
        if (mounted) {
          context.showWarningToaster(
            MessageService.getMessage('session_expired'),
            devMessage:
                'Biometric authentication expired, redirecting to login',
          );
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });

      // Handle different error types
      if (result.errorType == BiometricErrorType.userCancel) {
        // User cancelled, show alternative options
        return;
      } else if (result.errorType == BiometricErrorType.lockedOut ||
          result.errorType == BiometricErrorType.permanentlyLockedOut) {
        // Biometric is locked, redirect to regular login
        if (mounted) {
          context.showErrorToaster(
            MessageService.getMessage('biometric_not_available'),
            devMessage:
                'Biometric locked, redirecting to login: ${result.message}',
          );
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        // Other errors, show message and allow retry
        if (mounted) {
          context.showErrorToaster(
            MessageService.getMessage('biometric_setup_failed'),
            devMessage: 'Biometric login failed: ${result.message}',
          );
        }
      }
    }
  }

  void _usePasswordLogin() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  Widget _buildBiometricIcon() {
    if (_availableTypes.contains(BiometricType.face)) {
      return const Icon(Icons.face, size: 100, color: Color(0xFF4ECDC4));
    } else if (_availableTypes.contains(BiometricType.fingerprint)) {
      return const Icon(Icons.fingerprint, size: 100, color: Color(0xFF4ECDC4));
    } else {
      return const Icon(Icons.security, size: 100, color: Color(0xFF4ECDC4));
    }
  }

  String _getBiometricTitle() {
    if (_availableTypes.contains(BiometricType.face)) {
      return 'Use Face ID to Sign In';
    } else if (_availableTypes.contains(BiometricType.fingerprint)) {
      return 'Use Fingerprint to Sign In';
    } else {
      return 'Use Biometric to Sign In';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // App logo/title
              const SizedBox(height: 40),
              const Text(
                'AncientFlip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isAvailable) ...[
                      // Animated biometric icon
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isLoading ? _pulseAnimation.value : 1.0,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF4ECDC4).withOpacity(0.1),
                                border: Border.all(
                                  color: const Color(
                                    0xFF4ECDC4,
                                  ).withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Center(child: _buildBiometricIcon()),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // Title
                      Text(
                        _getBiometricTitle(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      // Status message
                      if (_isLoading)
                        const Text(
                          'Authenticating...',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        )
                      else
                        const Text(
                          'Touch the sensor or look at your device to continue',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),

                      const SizedBox(height: 40),

                      // Try again button (if not loading)
                      if (!_isLoading)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _authenticateWithBiometric,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4ECDC4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Try Again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ] else ...[
                      // Biometric not available
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.info_outline,
                            size: 100,
                            color: Colors.orange,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      const Text(
                        'Biometric Unavailable',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              // Use password button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _usePasswordLogin,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Use Password Instead',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
