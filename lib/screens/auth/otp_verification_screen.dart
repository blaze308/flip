import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../services/firebase_auth_service.dart';
import '../../services/message_service.dart';
import '../../services/optimistic_ui_service.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/modern_otp_input.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _otpKey = GlobalKey();

  bool _isResendEnabled = false;
  int _resendCountdown = 30;
  Timer? _timer;
  String _phoneNumber = '';
  String _verificationId = '';
  String _currentOtp = '';

  // Button states for loading UI
  ButtonState _verifyButtonState = const ButtonState();
  ButtonState _resendButtonState = const ButtonState();

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

    // Get arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _phoneNumber = args['phoneNumber'] ?? '';
          _verificationId = args['verificationId'] ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
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

  void _onOtpChanged(String value) {
    setState(() {
      _currentOtp = value;
    });

    // Clear any error state when user starts typing
    if (_verifyButtonState.isError && value.isNotEmpty) {
      setState(() {
        _verifyButtonState = const ButtonState();
      });
    }
  }

  void _onOtpCompleted(String value) {
    setState(() {
      _currentOtp = value;
    });

    // Auto-verify when all fields are filled
    if (value.length == 6) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _currentOtp.length == 6) {
          _verifyOtp();
        }
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otpCode = _currentOtp;

    if (otpCode.length != 6) {
      setState(() {
        _verifyButtonState = ButtonStateExtension.error(
          message: 'Please enter complete OTP code',
        );
      });

      // Clear error after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _verifyButtonState = const ButtonState();
          });
        }
      });
      return;
    }

    if (_verificationId.isEmpty) {
      setState(() {
        _verifyButtonState = ButtonStateExtension.error(
          message: 'Verification ID not found. Please try again.',
        );
      });

      // Clear error after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _verifyButtonState = const ButtonState();
          });
        }
      });
      return;
    }

    setState(() {
      _verifyButtonState = ButtonStateExtension.loading(
        message: 'Verifying OTP...',
      );
    });

    try {
      // Verify OTP using Firebase
      final result = await FirebaseAuthService.verifyPhoneNumber(
        verificationId: _verificationId,
        smsCode: otpCode,
      );

      if (result.success && result.user != null) {
        if (mounted) {
          setState(() {
            _verifyButtonState = ButtonStateExtension.success(
              message: 'Verification successful!',
            );
          });

          // Navigate after showing success
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _verifyButtonState = ButtonStateExtension.error(
              message: MessageService.getFirebaseErrorMessage(result.message),
            );
          });

          // Clear error after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _verifyButtonState = const ButtonState();
              });
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifyButtonState = ButtonStateExtension.error(
            message: 'Verification failed. Please try again.',
          );
        });

        // Clear error after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _verifyButtonState = const ButtonState();
            });
          }
        });
      }
    } finally {
      // Button state is managed by the individual success/error handlers
    }
  }

  Future<void> _resendOtp() async {
    if (!_isResendEnabled) return;

    setState(() {
      _resendButtonState = ButtonStateExtension.loading(
        message: 'Sending OTP...',
      );
    });

    try {
      // Simulate resend OTP
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() {
          _resendButtonState = ButtonStateExtension.success(
            message: 'OTP sent successfully!',
          );
        });

        _startResendTimer();

        // Clear success message after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _resendButtonState = const ButtonState();
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resendButtonState = ButtonStateExtension.error(
            message: 'Failed to send OTP. Please try again.',
          );
        });

        // Clear error after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _resendButtonState = const ButtonState();
            });
          }
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                            const Text(
                              'Verify Phone Number',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'We Have Sent Code To Your Phone Number',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.7),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _phoneNumber,
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

                      // Modern OTP Input
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: EnhancedOtpInput(
                          key: _otpKey,
                          length: 6,
                          onChanged: _onOtpChanged,
                          onCompleted: _onOtpCompleted,
                          autoFocus: true,
                          enabled: !_verifyButtonState.isLoading,
                          errorText:
                              _verifyButtonState.isError
                                  ? _verifyButtonState.message
                                  : null,
                          helperText:
                              'Enter the 6-digit code sent to $_phoneNumber',
                          autoSubmitDelay: const Duration(milliseconds: 500),
                        ),
                      ),

                      const Spacer(flex: 2),

                      const Spacer(flex: 1),

                      // Verify Button
                      AuthButton(
                        text: 'Verify',
                        onPressed: _verifyOtp,
                        buttonState: _verifyButtonState,
                        isPrimary: true,
                      ),

                      const SizedBox(height: 16),

                      // Send Again Button
                      AuthButton(
                        text:
                            _isResendEnabled
                                ? 'Send Again'
                                : 'Send Again (${_resendCountdown}s)',
                        onPressed: _isResendEnabled ? _resendOtp : null,
                        buttonState: _resendButtonState.copyWith(
                          isDisabled: !_isResendEnabled,
                        ),
                        isPrimary: false,
                      ),

                      const Spacer(flex: 2),
                    ],
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
