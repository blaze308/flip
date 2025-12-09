import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/message_service.dart';
import '../../widgets/custom_toaster.dart';

class PhoneRegistrationScreen extends StatefulWidget {
  const PhoneRegistrationScreen({super.key});

  @override
  State<PhoneRegistrationScreen> createState() =>
      _PhoneRegistrationScreenState();
}

class _PhoneRegistrationScreenState extends State<PhoneRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  Country _selectedCountry = Country.parse('US'); // Default to US

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
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove any non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 9) {
      return 'Phone number must be at least 9 digits';
    }

    if (digitsOnly.length > 15) {
      return 'Phone number cannot exceed 15 digits';
    }

    return null;
  }

  String _formatPhoneNumber(String value) {
    // Remove any non-digit characters
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    // Format based on length (US format as example)
    if (digitsOnly.length <= 3) {
      return digitsOnly;
    } else if (digitsOnly.length <= 6) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3)}';
    } else if (digitsOnly.length <= 10) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    } else {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6, 10)}';
    }
  }

  Future<void> _handlePhoneVerification() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final phoneNumber =
            '+${_selectedCountry.phoneCode}${_phoneController.text.replaceAll(RegExp(r'[^\d]'), '')}';

        // Send verification code using Firebase
        final result = await FirebaseAuthService.sendPhoneVerificationCode(
          phoneNumber: phoneNumber,
          onCodeSent: (String verificationId) {
            if (mounted) {
              // Navigate to OTP verification screen with verification ID
              Navigator.of(context).pushNamed(
                '/otp-verification',
                arguments: {
                  'phoneNumber': phoneNumber,
                  'verificationId': verificationId,
                },
              );
            }
          },
          onVerificationFailed: (String error) {
            if (mounted) {
              context.showErrorToaster(
                MessageService.getFirebaseErrorMessage(error),
                devMessage: 'Phone verification failed: $error',
              );
            }
          },
        );

        if (!result.success) {
          if (mounted) {
            context.showErrorToaster(
              MessageService.getFirebaseErrorMessage(result.message),
              devMessage: 'Phone registration failed: ${result.message}',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          context.showErrorToaster(
            MessageService.getMessage('network_error'),
            devMessage: 'Phone verification exception: ${e.toString()}',
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

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: const Color(0xFF34495E),
        textStyle: const TextStyle(color: Colors.white),
        searchTextStyle: const TextStyle(color: Colors.white),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          labelStyle: const TextStyle(color: Colors.white70),
          hintText: 'Start typing to search',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white30),
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white30),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        bottomSheetHeight: 500,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country;
        });
      },
    );
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

                        const Spacer(flex: 2),

                        // Title
                        const Text(
                          'Enter Your Phone\nNumber',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),

                        const Spacer(flex: 3),

                        // Phone Number Field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF34495E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              // Country code selector
                              InkWell(
                                onTap: _showCountryPicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedCountry.flagEmoji,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '+${_selectedCountry.phoneCode}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Divider
                              Container(
                                width: 1,
                                height: 24,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),

                              // Phone number input
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  validator: _validatePhoneNumber,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(15),
                                    TextInputFormatter.withFunction((
                                      oldValue,
                                      newValue,
                                    ) {
                                      final formatted = _formatPhoneNumber(
                                        newValue.text,
                                      );
                                      return TextEditingValue(
                                        text: formatted,
                                        selection: TextSelection.collapsed(
                                          offset: formatted.length,
                                        ),
                                      );
                                    }),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: 'Phone Number',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 16,
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
                          ),
                        ),

                        const Spacer(flex: 4),

                        // Verification Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : _handlePhoneVerification,
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

                        const SizedBox(height: 24),

                        // Later Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            child: const Text(
                              'Later',
                              style: TextStyle(
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
            );
          },
        ),
      ),
    );
  }
}
