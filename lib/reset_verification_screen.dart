import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'services/message_service.dart';
import 'widgets/custom_toaster.dart';

class ResetVerificationScreen extends StatefulWidget {
  const ResetVerificationScreen({super.key});

  @override
  State<ResetVerificationScreen> createState() =>
      _ResetVerificationScreenState();
}

class _ResetVerificationScreenState extends State<ResetVerificationScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  bool _isResendEnabled = false;
  int _resendCountdown = 30;
  Timer? _timer;
  String _resetMethod = 'email';
  String _contactInfo = '';

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
    _startResendTimer();

    // Auto-focus first field and get arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();

      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _resetMethod = args['method'] ?? 'email';
          _contactInfo = args['contactInfo'] ?? 'joseph****@gmail.com';
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _isResendEnabled = false;
    _resendCountdown = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _isResendEnabled = true;
        });
        timer.cancel();
      }
    });
  }

  void _onOtpChanged(String value, int index) {
    // Handle paste functionality - if user pastes a 6-digit code
    if (value.length > 1) {
      final pastedCode = value.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      ); // Keep only digits
      if (pastedCode.length <= 6) {
        // Fill the fields with pasted code
        for (int i = 0; i < 6; i++) {
          if (i < pastedCode.length) {
            _otpControllers[i].text = pastedCode[i];
          } else {
            _otpControllers[i].clear();
          }
        }
        // Focus the next empty field or unfocus if complete
        if (pastedCode.length < 6) {
          _focusNodes[pastedCode.length].requestFocus();
        } else {
          _focusNodes[5].unfocus();
        }
      }
      return;
    }

    if (value.isNotEmpty) {
      // Move to next field if not the last one
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last field filled, remove focus to show keyboard done
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      // Move to previous field when deleting
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all fields are filled
    if (_getOtpCode().length == 6) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _getOtpCode().length == 6) {
          _verifyCode();
        }
      });
    }
  }

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyCode() async {
    final otpCode = _getOtpCode();

    if (otpCode.length != 6) {
      context.showWarningToaster(
        'Please enter complete verification code',
        devMessage: 'User tried to verify with incomplete OTP: $otpCode',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate verification (in real app, verify with backend)
      await Future.delayed(const Duration(seconds: 2));

      // For demo purposes, accept any 6-digit code
      // In real app, verify against code sent to email/phone
      if (mounted) {
        context.showSuccessToaster(
          MessageService.getMessage('verification_success'),
          devMessage:
              'Reset verification successful for $_resetMethod: $_contactInfo',
        );

        // Navigate to new password screen with contact info
        Navigator.of(context).pushReplacementNamed(
          '/new-password',
          arguments: {
            'method': _resetMethod,
            'contactInfo': _contactInfo,
            'verified': true,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(
          MessageService.getMessage('verification_failed'),
          devMessage: 'Reset verification failed: ${e.toString()}',
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

  Future<void> _resendCode() async {
    if (!_isResendEnabled) return;

    try {
      // Simulate resend
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        context.showSuccessToaster(
          MessageService.getMessage('sending_code'),
          devMessage:
              'Resent verification code to $_resetMethod: $_contactInfo',
        );
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(
          MessageService.getMessage('error'),
          devMessage: 'Failed to resend verification code: ${e.toString()}',
        );
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Back button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
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

                          const Spacer(flex: 2),

                          // Title
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  _resetMethod == 'email'
                                      ? 'Verify Email'
                                      : 'Verify Phone',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _resetMethod == 'email'
                                      ? 'We Have Sent Code To Your Email'
                                      : 'We Have Sent Code To Your Phone Number',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _contactInfo,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(flex: 2),

                          // OTP Input Fields
                          Center(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Calculate responsive dimensions
                                final screenWidth = constraints.maxWidth;
                                final fieldCount = 6; // Always use 6 digits
                                final fieldWidth =
                                    (screenWidth - 80) /
                                    fieldCount; // Leave 80px for margins
                                final fieldSize = fieldWidth.clamp(40.0, 60.0);
                                final horizontalMargin =
                                    (screenWidth - (fieldSize * fieldCount)) /
                                    (fieldCount * 2 +
                                        2); // Distribute remaining space

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(fieldCount, (index) {
                                    return Container(
                                      width: fieldSize,
                                      height: fieldSize,
                                      margin: EdgeInsets.symmetric(
                                        horizontal: horizontalMargin.clamp(
                                          2.0,
                                          8.0,
                                        ),
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              _focusNodes[index].hasFocus
                                                  ? const Color(0xFF4ECDC4)
                                                  : Colors.white.withOpacity(
                                                    0.3,
                                                  ),
                                          width: 2,
                                        ),
                                      ),
                                      child: TextFormField(
                                        controller: _otpControllers[index],
                                        focusNode: _focusNodes[index],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        maxLength: 1,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: (fieldSize * 0.4).clamp(
                                            16.0,
                                            24.0,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          counterText: '',
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged:
                                            (value) =>
                                                _onOtpChanged(value, index),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),

                          const Spacer(flex: 1),

                          // Verify Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyCode,
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
                                        'Verify',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Send Again Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: TextButton(
                              onPressed: _isResendEnabled ? _resendCode : null,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.1),
                                foregroundColor:
                                    _isResendEnabled
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              child: Text(
                                _isResendEnabled
                                    ? 'Send Again'
                                    : 'Send Again (${_resendCountdown}s)',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(flex: 2),
                        ],
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
