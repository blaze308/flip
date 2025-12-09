import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/message_service.dart';
import '../../widgets/custom_toaster.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isAvailable = false;
  List<BiometricType> _availableTypes = [];
  String _statusMessage = '';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkBiometricAvailability();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final availability =
        await BiometricAuthService.checkBiometricAvailability();

    setState(() {
      _isLoading = false;
      _isAvailable = availability.isAvailable;
      _availableTypes = availability.availableTypes;
      _statusMessage = availability.message;
    });
  }

  Future<void> _enableBiometric() async {
    setState(() {
      _isLoading = true;
    });

    final success = await BiometricAuthService.enableBiometricAuth();

    if (success) {
      if (mounted) {
        context.showSuccessToaster(
          MessageService.getMessage('biometric_setup_success'),
          devMessage: 'Biometric authentication enabled successfully',
        );

        // Navigate to home screen
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        context.showErrorToaster(
          MessageService.getMessage('biometric_setup_failed'),
          devMessage: 'Failed to enable biometric authentication',
        );
      }
    }
  }

  void _skipBiometric() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Widget _buildBiometricIcon() {
    if (_availableTypes.contains(BiometricType.face)) {
      return const Icon(Icons.face, size: 80, color: Color(0xFF4ECDC4));
    } else if (_availableTypes.contains(BiometricType.fingerprint)) {
      return const Icon(Icons.fingerprint, size: 80, color: Color(0xFF4ECDC4));
    } else {
      return const Icon(Icons.security, size: 80, color: Color(0xFF4ECDC4));
    }
  }

  String _getBiometricTitle() {
    if (_availableTypes.contains(BiometricType.face)) {
      return 'Enable Face ID';
    } else if (_availableTypes.contains(BiometricType.fingerprint)) {
      return 'Enable Fingerprint';
    } else {
      return 'Enable Biometric Authentication';
    }
  }

  String _getBiometricDescription() {
    final List<String> types = [];

    if (_availableTypes.contains(BiometricType.face)) {
      types.add('Face ID');
    }
    if (_availableTypes.contains(BiometricType.fingerprint)) {
      types.add('Fingerprint');
    }
    if (_availableTypes.contains(BiometricType.iris)) {
      types.add('Iris');
    }

    if (types.isEmpty) {
      return 'Use biometric authentication for quick and secure access to your account.';
    } else if (types.length == 1) {
      return 'Use ${types[0]} for quick and secure access to your account.';
    } else {
      final lastType = types.removeLast();
      return 'Use ${types.join(', ')} or $lastType for quick and secure access to your account.';
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
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _skipBiometric,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF4ECDC4),
                            ),
                          ),
                        )
                        : _isAvailable
                        ? _buildAvailableContent()
                        : _buildUnavailableContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated biometric icon
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4ECDC4).withOpacity(0.1),
                border: Border.all(
                  color: const Color(0xFF4ECDC4).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(child: _buildBiometricIcon()),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            _getBiometricTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            _getBiometricDescription(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Benefits list
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildBenefitItem(
                  Icons.speed,
                  'Quick Access',
                  'Sign in instantly without typing passwords',
                ),
                const SizedBox(height: 16),
                _buildBenefitItem(
                  Icons.security,
                  'Enhanced Security',
                  'Your biometric data stays secure on your device',
                ),
                const SizedBox(height: 16),
                _buildBenefitItem(
                  Icons.privacy_tip,
                  'Privacy First',
                  'We never store your biometric information',
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Enable button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _enableBiometric,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        'Enable Biometric Authentication',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),

          const SizedBox(height: 16),

          // Maybe later button
          TextButton(
            onPressed: _isLoading ? null : _skipBiometric,
            child: const Text(
              'Maybe Later',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(Icons.info_outline, size: 80, color: Colors.orange),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          const Text(
            'Biometric Authentication Unavailable',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Message
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Continue button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _skipBiometric,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Continue to App',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4ECDC4).withOpacity(0.2),
          ),
          child: Icon(icon, color: const Color(0xFF4ECDC4), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
