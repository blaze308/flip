import 'package:flutter/material.dart';
import 'services/firebase_auth_service.dart';
import 'services/message_service.dart';
import 'widgets/custom_toaster.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();

  bool _isLoading = false;
  String _selectedMethod = 'email'; // 'email' or 'phone'
  bool _showInput = false;

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
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordReset() async {
    if (!_showInput) {
      context.showWarningToaster(
        'Please select a reset method first',
        devMessage: 'User tried to reset without selecting method',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final contactInfo = _inputController.text.trim();

      if (_selectedMethod == 'email') {
        // Send actual Firebase password reset email
        final result = await FirebaseAuthService.sendPasswordResetEmail(
          contactInfo,
        );

        if (mounted) {
          if (result.success) {
            context.showSuccessToaster(
              MessageService.getMessage('password_reset_sent'),
              devMessage: 'Firebase password reset email sent to: $contactInfo',
            );

            // Go back to login - user will handle reset via email link
            Navigator.of(context).pop();
          } else {
            context.showErrorToaster(
              MessageService.getFirebaseErrorMessage(result.message),
              devMessage: 'Firebase password reset failed: ${result.message}',
            );
          }
        }
      } else {
        // For phone method, send OTP and navigate to verification screen
        await Future.delayed(const Duration(seconds: 1)); // Simulate API call

        if (mounted) {
          context.showSuccessToaster(
            MessageService.getMessage('sending_code'),
            devMessage: 'Phone verification code sent to: $contactInfo',
          );

          Navigator.of(context).pushNamed(
            '/reset-verification',
            arguments: {
              'method': _selectedMethod,
              'contactInfo':
                  contactInfo.isNotEmpty ? contactInfo : '+1 ****-***-1234',
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(
          MessageService.getMessage('error'),
          devMessage: 'Password reset failed: ${e.toString()}',
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
      resizeToAvoidBottomInset: true,
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            // Back button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Title
                            const Text(
                              'Forget Password',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Subtitle
                            Text(
                              'Select which contact details should we use to reset your password',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Email Option
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedMethod = 'email';
                                  _showInput = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedMethod == 'email'
                                          ? const Color(
                                            0xFF4ECDC4,
                                          ).withOpacity(0.1)
                                          : const Color(0xFF34495E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        _selectedMethod == 'email'
                                            ? const Color(0xFF4ECDC4)
                                            : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: const Icon(
                                        Icons.email_outlined,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Email',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Code Send to your email',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.7,
                                              ),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_selectedMethod == 'email')
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF4ECDC4),
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Phone Option
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedMethod = 'phone';
                                  _showInput = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedMethod == 'phone'
                                          ? const Color(
                                            0xFF4ECDC4,
                                          ).withOpacity(0.1)
                                          : const Color(0xFF34495E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        _selectedMethod == 'phone'
                                            ? const Color(0xFF4ECDC4)
                                            : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: const Icon(
                                        Icons.phone_outlined,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Phone',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Code Send to your phone',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.7,
                                              ),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_selectedMethod == 'phone')
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF4ECDC4),
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Input field (shown after selection)
                            if (_showInput) ...[
                              const SizedBox(height: 24),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34495E),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextFormField(
                                  controller: _inputController,
                                  keyboardType:
                                      _selectedMethod == 'email'
                                          ? TextInputType.emailAddress
                                          : TextInputType.phone,
                                  style: const TextStyle(color: Colors.white),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return _selectedMethod == 'email'
                                          ? 'Email is required'
                                          : 'Phone number is required';
                                    }
                                    if (_selectedMethod == 'email') {
                                      if (!RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                      ).hasMatch(value)) {
                                        return 'Please enter a valid email address';
                                      }
                                    } else {
                                      if (value.length < 10) {
                                        return 'Please enter a valid phone number';
                                      }
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText:
                                        _selectedMethod == 'email'
                                            ? 'Enter your email address'
                                            : 'Enter your phone number',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    prefixIcon: Icon(
                                      _selectedMethod == 'email'
                                          ? Icons.email_outlined
                                          : Icons.phone_outlined,
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
                            ],

                            const Spacer(),

                            // Next Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _handlePasswordReset,
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
                                          'Next',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                              ),
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
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
