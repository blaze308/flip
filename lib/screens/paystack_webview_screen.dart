import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/paystack_service.dart';
import '../widgets/custom_toaster.dart';

/// Paystack Webview Screen
/// Displays Paystack payment page in a webview
class PaystackWebviewScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final int coins;
  final int diamonds;

  const PaystackWebviewScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.coins,
    required this.diamonds,
  });

  @override
  State<PaystackWebviewScreen> createState() => _PaystackWebviewScreenState();
}

class _PaystackWebviewScreenState extends State<PaystackWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('📱 Page started loading: $url');
            _checkPaymentStatus(url);
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
                'Failed to load payment page: ${error.description}',
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  void _checkPaymentStatus(String url) {
    // Check if payment was successful or cancelled
    if (url.contains('callback') || url.contains('success') || url.contains('close')) {
      print('🔍 Payment callback detected: $url');
      _verifyPayment();
    } else if (url.contains('cancel') || url.contains('failed')) {
      print('❌ Payment cancelled or failed');
      if (mounted) {
        Navigator.pop(context, false);
        ToasterService.showError(context, 'Payment cancelled');
      }
    }
  }

  Future<void> _verifyPayment() async {
    if (_isVerifying) return; // Prevent multiple verifications
    
    setState(() {
      _isVerifying = true;
    });

    try {
      print('🔍 Verifying payment with reference: ${widget.reference}');

      final result = await PaystackService.verifyTransaction(
        reference: widget.reference,
        context: context,
      );

      if (result != null && result['success'] == true) {
        print('✅ Payment verified successfully');

        // Complete coin purchase on backend
        final success = await PaystackService.completeCoinPurchase(
          reference: widget.reference,
          coins: widget.coins,
          context: context,
        );

        if (mounted) {
          Navigator.pop(context, success);
        }
      } else {
        print('❌ Payment verification failed');
        if (mounted) {
          Navigator.pop(context, false);
        }
      }
    } catch (e) {
      print('❌ Payment verification error: $e');
      if (mounted) {
        ToasterService.showError(context, 'Verification failed: $e');
        Navigator.pop(context, false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Complete Payment',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showCancelDialog();
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading || _isVerifying)
            Container(
              color: const Color(0xFF0A0E21),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF4ECDC4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isVerifying ? 'Verifying payment...' : 'Loading payment page...',
                      style: const TextStyle(
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

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Cancel Payment?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to cancel this payment?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, false); // Close webview
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}

