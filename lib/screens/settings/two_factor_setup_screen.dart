import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/message_service.dart';
import '../../widgets/custom_toaster.dart';

/// Two-Factor Authentication Setup Screen
/// Enroll or unenroll SMS-based 2FA via Firebase MFA
class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _reAuthDone = false;
  bool _isEnrolled = false;
  bool _enrolledCheckDone = false;
  Country _selectedCountry = Country.parse('US');

  bool get _hasEmail => (FirebaseAuthService.currentUser?.email ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _checkEnrolled();
  }

  Future<void> _checkEnrolled() async {
    final enrolled = await FirebaseAuthService.is2FAEnrolled();
    if (mounted) {
      setState(() {
        _isEnrolled = enrolled;
        _enrolledCheckDone = true;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 9) return 'Phone number must be at least 9 digits';
    return null;
  }

  String _formatPhone(String value) {
    final d = value.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length <= 3) return d;
    if (d.length <= 6) return '${d.substring(0, 3)}-${d.substring(3)}';
    if (d.length <= 10) return '${d.substring(0, 3)}-${d.substring(3, 6)}-${d.substring(6)}';
    return '${d.substring(0, 3)}-${d.substring(3, 6)}-${d.substring(6, 10)}';
  }

  Future<void> _reAuthenticate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await FirebaseAuthService.reauthenticateWithPassword(
        _passwordController.text,
      );
      if (mounted) {
        if (result.success) {
          setState(() => _reAuthDone = true);
          ToasterService.showSuccess(context, 'Verified. Now add your phone.');
        } else {
          ToasterService.showError(context, result.message);
        }
      }
    } catch (e) {
      if (mounted) ToasterService.showError(context, 'Re-authentication failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMfaCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final phone = '+${_selectedCountry.phoneCode}${_phoneController.text.replaceAll(RegExp(r'[^\d]'), '')}';
      final result = await FirebaseAuthService.sendPhoneVerificationCodeForMFA(
        phoneNumber: phone,
        onCodeSent: (String verificationId) {
          if (mounted) {
            Navigator.of(context).pushNamed(
              '/otp-verification',
              arguments: {
                'phoneNumber': phone,
                'verificationId': verificationId,
                'mfaEnrollMode': true,
              },
            );
          }
        },
        onVerificationFailed: (String error) {
          if (mounted) {
            ToasterService.showError(
              context,
              MessageService.getFirebaseErrorMessage(error),
            );
          }
        },
      );
      if (!result.success && mounted) {
        ToasterService.showError(context, result.message);
      }
    } catch (e) {
      if (mounted) ToasterService.showError(context, 'Failed to send code');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unenroll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text('Disable 2FA', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to disable two-factor authentication? Your account will be less secure.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final result = await FirebaseAuthService.unenroll2FA();
      if (mounted) {
        if (result.success) {
          ToasterService.showSuccess(context, result.message);
          _checkEnrolled();
        } else {
          ToasterService.showError(context, result.message);
        }
      }
    } catch (e) {
      if (mounted) ToasterService.showError(context, 'Failed to disable 2FA');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        setState(() => _selectedCountry = country);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_enrolledCheckDone) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          title: const Text('Two-Factor Authentication', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1D1E33),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Two-Factor Authentication', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isEnrolled) ...[
                Card(
                  color: const Color(0xFF1D1E33),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.security, color: Color(0xFF4ECDC4), size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '2FA is enabled',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your account is protected with two-factor authentication.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _unenroll,
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Disable 2FA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else if (!_hasEmail) ...[
                Card(
                  color: const Color(0xFF1D1E33),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF4ECDC4), size: 32),
                        const SizedBox(height: 12),
                        const Text(
                          '2FA requires email/password account',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You signed in with a social provider. To enable two-factor authentication, add an email and password to your account first.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (!_reAuthDone) ...[
                const Text(
                  'Enter your password to continue. This verifies your identity before enabling 2FA.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  validator: _validatePassword,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Your account password',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: const Color(0xFF1D1E33),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _reAuthenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
              ] else ...[
                const Text(
                  'Enter the phone number to receive verification codes when signing in.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _showCountryPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone, color: Colors.white.withValues(alpha: 0.7), size: 20),
                              const SizedBox(width: 8),
                              Text(_selectedCountry.flagEmoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 4),
                              Text(
                                '+${_selectedCountry.phoneCode}',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.7), size: 20),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.2)),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          validator: _validatePhone,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                            TextInputFormatter.withFunction((oldValue, newValue) {
                              final f = _formatPhone(newValue.text);
                              return TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
                            }),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Phone Number',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendMfaCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Text('Send Verification Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
