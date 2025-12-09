import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/wallet_service.dart';
import '../services/profile_service.dart';
import '../widgets/custom_toaster.dart';

/// Transfer Dialog
/// Allows users to transfer coins or diamonds to another user
class TransferDialog extends StatefulWidget {
  final UserModel? recipient;

  const TransferDialog({super.key, this.recipient});

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  UserModel? _selectedRecipient;
  String _selectedCurrency = 'coins';
  bool _isTransferring = false;
  bool _isSearching = false;
  List<UserModel> _searchResults = [];

  @override
  void initState() {
    super.initState();
    if (widget.recipient != null) {
      _selectedRecipient = widget.recipient;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // In a real app, you would have a user search API
      // For now, we'll use the followers list as a demo
      final followers = await ProfileService.getFollowers();

      if (mounted) {
        setState(() {
          _searchResults = followers
              .where((user) =>
                  user.displayName.toLowerCase().contains(query.toLowerCase()) ||
                  user.username.toLowerCase().contains(query.toLowerCase()))
              .toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _handleTransfer() async {
    if (_selectedRecipient == null) {
      ToasterService.showError(context, 'Please select a recipient');
      return;
    }

    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ToasterService.showError(context, 'Please enter a valid amount');
      return;
    }

    setState(() => _isTransferring = true);

    try {
      await WalletService.transferCoins(
        recipientId: _selectedRecipient!.id,
        currency: _selectedCurrency,
        amount: amount,
        message: _messageController.text.isNotEmpty
            ? _messageController.text
            : null,
      );

      if (mounted) {
        setState(() => _isTransferring = false);
        ToasterService.showSuccess(
          context,
          'Transfer successful! $amount ${_selectedCurrency} sent to ${_selectedRecipient!.displayName}',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTransferring = false);
        ToasterService.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1D1E33),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  '💸 Transfer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recipient Selection
            if (_selectedRecipient == null) ...[
              const Text(
                'Select Recipient',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: _searchUsers,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0A0E21),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isSearching)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                )
              else if (_searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.profileImageUrl != null
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                          child: user.profileImageUrl == null
                              ? Text(user.initials)
                              : null,
                        ),
                        title: Text(
                          user.displayName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedRecipient = user;
                            _searchController.clear();
                            _searchResults = [];
                          });
                        },
                      );
                    },
                  ),
                ),
            ] else ...[
              // Selected Recipient Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E21),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: _selectedRecipient!.profileImageUrl != null
                          ? NetworkImage(_selectedRecipient!.profileImageUrl!)
                          : null,
                      child: _selectedRecipient!.profileImageUrl == null
                          ? Text(_selectedRecipient!.initials)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedRecipient!.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '@${_selectedRecipient!.username}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (widget.recipient == null)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          setState(() => _selectedRecipient = null);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Currency Toggle
              const Text(
                'Currency',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E21),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCurrencyTab('coins', '🪙 Coins'),
                    ),
                    Expanded(
                      child: _buildCurrencyTab('diamonds', '💎 Diamonds'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount Input
              const Text(
                'Amount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Text(
                    _selectedCurrency == 'coins' ? '🪙' : '💎',
                    style: const TextStyle(fontSize: 24),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 50),
                  filled: true,
                  fillColor: const Color(0xFF0A0E21),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Message Input
              const Text(
                'Message (Optional)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLength: 200,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add a message...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF0A0E21),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 24),

              // Transfer Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isTransferring ? null : _handleTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isTransferring
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send Transfer',
                          style: TextStyle(
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

  Widget _buildCurrencyTab(String currency, String label) {
    final isSelected = _selectedCurrency == currency;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCurrency = currency);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4ECDC4) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

