import 'package:flutter/material.dart';
import 'services/token_auth_service.dart';
import 'services/biometric_auth_service.dart';
import 'services/message_service.dart';
import 'widgets/custom_toaster.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _biometricAvailable = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _checkBiometricAvailability();

    // Check for success message from password reset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['message'] != null) {
        context.showSuccessToaster(
          args['message'],
          devMessage: 'Login screen message: ${args['message']}',
        );
      }
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final isEnabled = await BiometricAuthService.isBiometricEnabled();
    final availability =
        await BiometricAuthService.checkBiometricAvailability();

    setState(() {
      _biometricAvailable = isEnabled && availability.isAvailable;
    });
  }

  Future<void> _handleBiometricLogin() async {
    setState(() {
      _isLoading = true;
    });

    final result = await BiometricAuthService.quickLogin();

    if (result.success) {
      // Check if user is authenticated with token service
      if (TokenAuthService.isAuthenticated) {
        // User is authenticated, they should already be on home screen
        // This shouldn't happen in normal flow
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // Need to re-authenticate
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          context.showWarningToaster(
            MessageService.getMessage('session_expired'),
            devMessage: 'Biometric authentication expired, requiring re-login',
          );
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });

      if (result.errorType != BiometricErrorType.userCancel) {
        if (mounted) {
          context.showErrorToaster(
            MessageService.getMessage('biometric_setup_failed'),
            devMessage: 'Biometric authentication failed: ${result.message}',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        print(
          '🔐 LoginScreen: Attempting email login for: ${_emailController.text.trim()}',
        );

        final result = await TokenAuthService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (result.success && mounted) {
          final user = TokenAuthService.currentUser;

          // Log successful login
          print('🔐 LoginScreen: Email login successful!');
          if (user != null) {
            print('   - ID: ${user.id}');
            print('   - Email: ${user.email}');
            print('   - Display Name: ${user.displayName}');
            print('   - Session will persist: 90 days');
            print('   - Is New User: ${result.isNewUser}');
          } else {
            print('   - Warning: Login successful but user data is null');
          }

          // Check if this is a new user (incomplete signup recovery)
          if (result.isNewUser) {
            context.showSuccessToaster(
              'Welcome! Please complete your profile to continue.',
              devMessage:
                  'Incomplete signup recovered, redirecting to complete profile',
            );
            Navigator.of(context).pushReplacementNamed('/complete-profile');
          } else {
            context.showSuccessToaster(
              'Welcome back, ${user?.displayName ?? 'User'}! ${MessageService.getMessage('login_success')}',
              devMessage: 'Email login successful',
            );

            // Debug: Show session info
            final sessionInfo = await TokenAuthService.getSessionInfo();
            print('🔐 Session Info: $sessionInfo');

            // Manual navigation to home screen
            print('🔐 LoginScreen: Navigating to home screen...');
            Navigator.of(context).pushReplacementNamed('/');
          }
        } else if (mounted) {
          print('🔐 LoginScreen: Email login failed - ${result.message}');
          context.showErrorToaster(
            MessageService.getFirebaseErrorMessage(result.message),
            devMessage: 'Email login failed: ${result.message}',
          );
        }
      } catch (e) {
        if (mounted) {
          context.showErrorToaster(
            MessageService.getMessage('network_error'),
            devMessage: 'Login exception: ${e.toString()}',
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔐 LoginScreen: Attempting Google login...');
      final result = await TokenAuthService.signInWithGoogle(isSignup: false);

      if (result.success) {
        if (mounted) {
          final user = TokenAuthService.currentUser;
          // Log successful Google login
          print('🔐 LoginScreen: Google login successful!');
          if (user != null) {
            print('   - ID: ${user.id}');
            print('   - Email: ${user.email}');
            print('   - Display Name: ${user.displayName}');
            print('   - Profile Image: ${user.photoURL ?? "No image"}');
          }

          context.showSuccessToaster(
            'Welcome back, ${user?.displayName ?? 'User'}! ${MessageService.getMessage('login_success')}',
            devMessage: 'Google login successful: ${result.message}',
          );

          // Manual navigation to home screen
          print('🔐 LoginScreen: Navigating to home screen...');
          Navigator.of(context).pushReplacementNamed('/');
        }
      } else {
        if (mounted) {
          print('🔐 LoginScreen: Google login failed - ${result.message}');
          context.showErrorToaster(
            MessageService.getFirebaseErrorMessage(result.message),
            devMessage: 'Google login failed: ${result.message}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(
          MessageService.getMessage('network_error'),
          devMessage: 'Google sign in exception: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔐 LoginScreen: Attempting Apple login...');
      final result = await TokenAuthService.signInWithApple(isSignup: false);

      if (result.success) {
        if (mounted) {
          final user = TokenAuthService.currentUser;
          // Log successful Apple login
          print('🔐 LoginScreen: Apple login successful!');
          if (user != null) {
            print('   - ID: ${user.id}');
            print('   - Email: ${user.email}');
            print('   - Display Name: ${user.displayName}');
            print('   - Profile Image: ${user.photoURL ?? "No image"}');
          }

          context.showSuccessToaster(
            'Welcome back, ${user?.displayName ?? 'User'}! ${MessageService.getMessage('login_success')}',
            devMessage: 'Apple login successful: ${result.message}',
          );

          // Manual navigation to home screen
          print('🔐 LoginScreen: Navigating to home screen...');
          Navigator.of(context).pushReplacementNamed('/');
        }
      } else {
        if (mounted) {
          print('🔐 LoginScreen: Apple login failed - ${result.message}');
          context.showErrorToaster(
            MessageService.getFirebaseErrorMessage(result.message),
            devMessage: 'Apple login failed: ${result.message}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(
          MessageService.getMessage('network_error'),
          devMessage: 'Apple sign in exception: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Skip button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton.icon(
                            onPressed: () async {
                              await TokenAuthService.skipToHome();
                              if (mounted) {
                                Navigator.of(context).pushReplacementNamed('/');
                              }
                            },
                            icon: const Icon(
                              Icons.skip_next,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: const Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Title
                        const Text(
                          'Login Your\nAccount',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Email Field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF34495E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            validator: _validateEmail,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter Your Email',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Password Field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF34495E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextFormField(
                            controller: _passwordController,
                            validator: _validatePassword,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Forget Password (Remember Me removed - users stay logged in by default)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).pushNamed('/forget-password');
                              },
                              child: Text(
                                'Forget Password ?',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4ECDC4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                          ),
                        ),

                        // Biometric Login Button (if available)
                        if (_biometricAvailable) ...[
                          const SizedBox(height: 16),

                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withOpacity(0.3),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withOpacity(0.3),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Biometric Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isLoading ? null : _handleBiometricLogin,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4ECDC4),
                                side: const BorderSide(
                                  color: Color(0xFF4ECDC4),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.fingerprint, size: 24),
                              label: const Text(
                                'Use Biometric',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Register Link
                        Center(
                          child: RichText(
                            text: TextSpan(
                              text: "Create New Account? ",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                              children: [
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed('/register');
                                    },
                                    child: const Text(
                                      'Sign up',
                                      style: TextStyle(
                                        color: Color(0xFF4ECDC4),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'Continue With Accounts',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Social Login Buttons
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34495E),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextButton(
                                  onPressed:
                                      _isLoading ? null : _handleGoogleSignIn,
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34495E),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(
                                      context,
                                    ).pushNamed('/phone-registration');
                                  },
                                  child: const Icon(
                                    Icons.phone,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34495E),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextButton(
                                  onPressed:
                                      _isLoading ? null : _handleAppleSignIn,
                                  child: const Icon(
                                    Icons.apple,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
