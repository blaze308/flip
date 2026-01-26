import 'package:flutter/material.dart';
import '../models/gift_model.dart';
import '../services/gift_service.dart';
import '../widgets/custom_toaster.dart';
import '../widgets/purchase_dialog_v2.dart';

/// Gift Payment Dialog
/// Shows payment options when user doesn't have enough coins to send a gift
class GiftPaymentDialog extends StatefulWidget {
  final GiftModel gift;
  final String receiverId;
  final String context;
  final String? contextId;
  final int quantity;
  final int required;
  final int current;
  final int shortfall;

  const GiftPaymentDialog({
    super.key,
    required this.gift,
    required this.receiverId,
    required this.context,
    this.contextId,
    this.quantity = 1,
    required this.required,
    required this.current,
    required this.shortfall,
  });

  @override
  State<GiftPaymentDialog> createState() => _GiftPaymentDialogState();
}

class _GiftPaymentDialogState extends State<GiftPaymentDialog> {
  bool _isProcessing = false;

  Future<void> _handlePayment() async {
    // Show purchase dialog to buy coins
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const PurchaseDialogV2(),
    );

    if (result == true && mounted) {
      // Coins purchased, now try to send gift again
      setState(() => _isProcessing = true);

      final sendResult = await GiftService.sendGift(
        giftId: widget.gift.id,
        receiverId: widget.receiverId,
        context: widget.context,
        contextId: widget.contextId,
        quantity: widget.quantity,
      );

      if (mounted) {
        setState(() => _isProcessing = false);

        if (sendResult['success'] == true) {
          ToasterService.showSuccess(context, 'Gift sent successfully!');
          Navigator.pop(context, true);
        } else {
          ToasterService.showError(
            context,
            sendResult['message'] ?? 'Failed to send gift',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1D1E33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Color(0xFF4ECDC4),
                size: 48,
              ),
            ),

            const SizedBox(height: 16),

            // Title
            const Text(
              'Insufficient Coins',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            // Gift info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard, color: Color(0xFF4ECDC4)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.gift.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.quantity}x ${widget.gift.weight} coins',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Balance info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildBalanceRow(
                    'Current Balance',
                    widget.current,
                    Colors.grey,
                  ),
                  const Divider(color: Colors.grey, height: 24),
                  _buildBalanceRow(
                    'Required',
                    widget.required,
                    const Color(0xFF4ECDC4),
                  ),
                  const Divider(color: Colors.grey, height: 24),
                  _buildBalanceRow('Need', widget.shortfall, Colors.orange),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isProcessing
                            ? null
                            : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handlePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isProcessing
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Buy Coins',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, int amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Row(
          children: [
            const Icon(Icons.diamond, color: Color(0xFFfcb69f), size: 16),
            const SizedBox(width: 4),
            Text(
              amount.toString(),
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
