import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../widgets/payment_method_card.dart';
import '../../widgets/ancient_flippy_pay_details.dart';
import '../../widgets/google_pay_details.dart';
import '../../widgets/paystack_details.dart';
import '../../widgets/custom_toaster.dart';
import '../../services/payment_service.dart';

/// Payment Methods Screen
/// Modern payment method management for AncientFlip Pay, Google Pay, and Paystack
class PaymentMethodsScreen extends StatefulWidget {
  final UserModel user;

  const PaymentMethodsScreen({super.key, required this.user});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _isLoading = false;
  String? _selectedPaymentMethod = 'ancient_pay';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Payment Methods',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment method selection cards
              PaymentMethodCard(
                title: 'AncientFlip Pay',
                description: 'Fast and secure in-app payment',
                icon: Icons.wallet,
                isSelected: _selectedPaymentMethod == 'ancient_pay',
                onTap: () => _selectPaymentMethod('ancient_pay'),
              ),
              const SizedBox(height: 12),
              PaymentMethodCard(
                title: 'Google Pay',
                description: 'Pay with your Google account',
                icon: Icons.payment,
                isSelected: _selectedPaymentMethod == 'google_pay',
                onTap: () => _selectPaymentMethod('google_pay'),
              ),
              const SizedBox(height: 12),
              PaymentMethodCard(
                title: 'Paystack',
                description: 'Available in GH, NG, ZA, KE',
                icon: Icons.credit_card,
                isSelected: _selectedPaymentMethod == 'paystack',
                onTap: () => _selectPaymentMethod('paystack'),
              ),
              const SizedBox(height: 32),
              // Details section
              _buildDetails(),
              const SizedBox(height: 32),
              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    switch (_selectedPaymentMethod) {
      case 'ancient_pay':
        return AncientFlipPayDetails(user: widget.user);
      case 'google_pay':
        return GooglePayDetails(user: widget.user);
      case 'paystack':
        return PaystackDetails(user: widget.user);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4ECDC4).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSetPaymentMethod,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Set as Primary Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF4ECDC4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF4ECDC4), width: 1.5),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close, size: 18),
              SizedBox(width: 8),
              Text(
                'Close',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectPaymentMethod(String method) {
    setState(() {
      _selectedPaymentMethod = method;
    });
  }

  Future<void> _handleSetPaymentMethod() async {
    if (_selectedPaymentMethod == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await PaymentService.setPreferredPaymentMethod(
        method: _selectedPaymentMethod!,
      );

      if (mounted) {
        if (result['success']) {
          ToasterService.showSuccess(
            context,
            'Payment method updated successfully',
          );
          Navigator.pop(context);
        } else {
          ToasterService.showError(
            context,
            result['message'] ?? 'Failed to update payment method',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToasterService.showError(
          context,
          'Error updating payment method: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
