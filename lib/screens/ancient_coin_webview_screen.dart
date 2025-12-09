import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/ancient_coin_service.dart';
import '../widgets/custom_toaster.dart';

/// AncientCoin OAuth Webview Screen
/// Handles AncientCoin OAuth authorization flow
class AncientCoinWebviewScreen extends StatefulWidget {
  const AncientCoinWebviewScreen({super.key});

  @override
  State<AncientCoinWebviewScreen> createState() => _AncientCoinWebviewScreenState();
}

class _AncientCoinWebviewScreenState extends State<AncientCoinWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final authUrl = AncientCoinService.getAuthorizationUrl();
    print('🔐 Loading AncientCoin OAuth: $authUrl');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('📱 Page started loading: $url');
            _checkAuthCallback(url);
          },
          onPageFinished: (String url) {
            print('✅ Page finished loading: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ Web resource error: ${error.description}');
            if (mounted) {
              ToasterService.showError(
                context,
                'Failed to load authorization page: ${error.description}',
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(authUrl));
  }

  void _checkAuthCallback(String url) {
    // Check if this is the callback URL with authorization code
    if (url.contains('ancientsflip.com/callback') || url.contains('code=')) {
      print('🔍 Authorization callback detected: $url');
      
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      
      if (code != null && code.isNotEmpty) {
        _handleAuthorizationCode(code);
      } else {
        print('❌ No authorization code found in callback');
        if (mounted) {
          Navigator.pop(context, false);
          ToasterService.showError(context, 'Authorization failed');
        }
      }
    }
  }

  Future<void> _handleAuthorizationCode(String code) async {
    print('🔐 Exchanging authorization code for token...');
    
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await AncientCoinService.getAccessToken(code, context);
      
      if (mounted) {
        Navigator.pop(context, success);
      }
    } catch (e) {
      print('❌ Authorization error: $e');
      if (mounted) {
        ToasterService.showError(context, 'Authorization failed: $e');
        Navigator.pop(context, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Connect AncientCoin',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context, false);
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: const Color(0xFF0A0E21),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF4ECDC4),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading AncientCoin authorization...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// AncientCoin Payment Screen
/// Handles OTP input and payment confirmation
class AncientCoinPaymentScreen extends StatefulWidget {
  final double amount;
  final String currency;
  final int coins;

  const AncientCoinPaymentScreen({
    super.key,
    required this.amount,
    required this.currency,
    required this.coins,
  });

  @override
  State<AncientCoinPaymentScreen> createState() => _AncientCoinPaymentScreenState();
}

class _AncientCoinPaymentScreenState extends State<AncientCoinPaymentScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoadingOtp = false;
  bool _isPaying = false;
  bool _otpSent = false;
  double? _cashableAmount;

  @override
  void initState() {
    super.initState();
    _loadCashableAmount();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadCashableAmount() async {
    final amount = await AncientCoinService.getCashableAmount(widget.currency, context);
    if (mounted) {
      setState(() {
        _cashableAmount = amount;
      });
    }
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) {
      ToasterService.showError(context, 'Please enter your email');
      return;
    }

    setState(() => _isLoadingOtp = true);

    final success = await AncientCoinService.sendOtp(_emailController.text, context);

    if (mounted) {
      setState(() {
        _isLoadingOtp = false;
        _otpSent = success;
      });
    }
  }

  Future<void> _handlePayment() async {
    if (_otpController.text.isEmpty) {
      ToasterService.showError(context, 'Please enter OTP');
      return;
    }

    setState(() => _isPaying = true);

    final success = await AncientCoinService.payWithWallet(
      amount: widget.amount,
      otp: _otpController.text,
      currency: widget.currency,
      coins: widget.coins,
      context: context,
    );

    if (mounted) {
      setState(() => _isPaying = false);

      if (success) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'AncientCoin Payment',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '${widget.currency} ${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'You will receive:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '${widget.coins} coins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_cashableAmount != null) ...[
                    const Divider(color: Colors.white30, height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Wallet Balance:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          '${widget.currency} ${_cashableAmount!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Email Input
            const Text(
              'Email Address',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your email',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1D1E33),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _otpSent
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
              enabled: !_otpSent,
            ),
            const SizedBox(height: 16),

            // Send OTP Button
            if (!_otpSent)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoadingOtp ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoadingOtp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send OTP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

            // OTP Input (shown after OTP is sent)
            if (_otpSent) ...[
              const Text(
                'Enter OTP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter 6-digit OTP',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1D1E33),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLength: 6,
              ),
              const SizedBox(height: 16),

              // Pay Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPaying ? null : _handlePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isPaying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Complete Payment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

