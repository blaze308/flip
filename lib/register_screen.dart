import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/token_auth_service.dart';
import 'services/message_service.dart';
import 'widgets/custom_toaster.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    // Trim the value first
    final trimmedValue = value?.trim();

    if (trimmedValue == null || trimmedValue.isEmpty) {
      return 'Username is required';
    }
    if (trimmedValue.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (trimmedValue.length > 20) {
      return 'Username must be less than 20 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmedValue)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
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
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    // if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
    //   return 'Password must contain uppercase, lowercase, and number';
    // }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('📝 RegisterScreen: Attempting registration...');
        print('   - Username: ${_usernameController.text.trim()}');
        print('   - Email: ${_emailController.text.trim()}');

        // Call token auth registration
        final result = await TokenAuthService.registerWithEmailAndPassword(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (result.success) {
          // Full success - Firebase + Backend sync worked
          if (mounted) {
            final user = TokenAuthService.currentUser;
            // Log successful registration
            print('📝 RegisterScreen: Registration successful!');
            if (user != null) {
              print('   - ID: ${user.id}');
              print('   - Email: ${user.email}');
              print('   - Display Name: ${user.displayName}');
              print('   - Profile Image: ${user.photoURL ?? "No image"}');
            }
            print('   - Backend Sync: Success');
            print('   - Is New User: ${result.isNewUser}');

            context.showSuccessToaster(
              'Welcome ${user?.displayName ?? 'User'}! ${MessageService.getMessage('registration_success')}',
              devMessage: 'User registration successful: ${result.message}',
            );

            // Check if this is a new user - if so, show complete profile screen
            // Otherwise go directly to biometric setup
            if (result.isNewUser) {
              Navigator.of(context).pushReplacementNamed('/complete-profile');
            } else {
              Navigator.of(context).pushReplacementNamed('/biometric-setup');
            }
          }
        } else {
          // Complete failure - Firebase registration failed
          if (mounted) {
            print('📝 RegisterScreen: Registration failed completely');
            print('   - Error: ${result.message}');

            // Check if it's an "already exists" error
            final errorMessage = result.message.toLowerCase();

            if (errorMessage.contains('already exists') ||
                errorMessage.contains('email already in use') ||
                errorMessage.contains('email-already-in-use')) {
              // Show helpful dialog to redirect to login
              // This handles both: real duplicates AND incomplete signups
              showDialog(
                context: context,
                barrierDismissible: false,
                builder:
                    (context) => AlertDialog(
                      backgroundColor: const Color(0xFF2C3E50),
                      title: const Text(
                        'Account Found',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'An account with this email already exists. Please log in to continue.\n\nIf your signup was incomplete, logging in will let you complete your profile.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ECDC4),
                          ),
                          child: const Text('Go to Login'),
                        ),
                      ],
                    ),
              );
            } else {
              context.showErrorToaster(
                MessageService.getFirebaseErrorMessage(result.message),
                devMessage: 'Registration failed: ${result.message}',
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          print('📝 RegisterScreen: Registration exception: $e');
          context.showErrorToaster(
            MessageService.getMessage('network_error'),
            devMessage: 'Registration exception: ${e.toString()}',
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

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await TokenAuthService.signInWithGoogle(isSignup: true);

      if (result.success) {
        if (mounted) {
          context.showSuccessToaster(
            'Welcome ${TokenAuthService.currentUser?.displayName ?? 'User'}! ${MessageService.getMessage('registration_success')}',
            devMessage: 'Google registration successful: ${result.message}',
          );

          // Check if this is a new user - if so, show complete profile screen
          // Otherwise go directly to biometric setup
          if (result.isNewUser) {
            Navigator.of(context).pushReplacementNamed('/complete-profile');
          } else {
            Navigator.of(context).pushReplacementNamed('/biometric-setup');
          }
        }
      } else {
        if (mounted) {
          context.showErrorToaster(
            MessageService.getFirebaseErrorMessage(result.message),
            devMessage: 'Google OAuth registration failed: ${result.message}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(
          MessageService.getMessage('network_error'),
          devMessage: 'Google sign up exception: ${e.toString()}',
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

  Future<void> _handleAppleSignUp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await TokenAuthService.signInWithApple(isSignup: true);

      if (result.success) {
        if (mounted) {
          context.showSuccessToaster(
            'Welcome ${TokenAuthService.currentUser?.displayName ?? 'User'}! ${MessageService.getMessage('registration_success')}',
            devMessage: 'Apple registration successful: ${result.message}',
          );

          // Check if this is a new user - if so, show complete profile screen
          // Otherwise go directly to biometric setup
          if (result.isNewUser) {
            Navigator.of(context).pushReplacementNamed('/complete-profile');
          } else {
            Navigator.of(context).pushReplacementNamed('/biometric-setup');
          }
        }
      } else {
        if (mounted) {
          context.showErrorToaster(
            MessageService.getFirebaseErrorMessage(result.message),
            devMessage: 'Apple OAuth registration failed: ${result.message}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(
          MessageService.getMessage('network_error'),
          devMessage: 'Apple sign up exception: ${e.toString()}',
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
                          'Create your\nAccount',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Username Field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF34495E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextFormField(
                            controller: _usernameController,
                            validator: _validateUsername,
                            style: const TextStyle(color: Colors.white),
                            textCapitalization: TextCapitalization.none,
                            autocorrect: false,
                            decoration: InputDecoration(
                              hintText: 'Username (e.g., john_doe123)',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.alternate_email,
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

                        // Confirm Password Field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF34495E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextFormField(
                            controller: _confirmPasswordController,
                            validator: _validateConfirmPassword,
                            obscureText: !_isConfirmPasswordVisible,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Confirm Password',
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
                                    _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible;
                                  });
                                },
                                icon: Icon(
                                  _isConfirmPasswordVisible
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

                        const SizedBox(height: 32),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
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
                                      'Register',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sign In Link
                        Center(
                          child: RichText(
                            text: TextSpan(
                              text: 'Already Have An Account? ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                              children: [
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pushNamed('/login');
                                    },
                                    child: const Text(
                                      'Sign In',
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
                                      _isLoading ? null : _handleGoogleSignUp,
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
                                      _isLoading ? null : _handleAppleSignUp,
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
