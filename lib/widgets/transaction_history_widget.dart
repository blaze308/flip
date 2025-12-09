import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

/// Transaction History Widget
/// Displays a filterable list of transactions with detailed information
class TransactionHistoryWidget extends StatefulWidget {
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? filterType; // 'all', 'purchase', 'gift', 'reward', etc.
  final VoidCallback? onRefresh;

  const TransactionHistoryWidget({
    super.key,
    required this.transactions,
    this.isLoading = false,
    this.filterType,
    this.onRefresh,
  });

  @override
  State<TransactionHistoryWidget> createState() =>
      _TransactionHistoryWidgetState();
}

class _TransactionHistoryWidgetState extends State<TransactionHistoryWidget> {
  late List<TransactionModel> _filteredTransactions;
  String _selectedFilter = 'all';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.filterType ?? 'all';
    _applyFilters();
  }

  @override
  void didUpdateWidget(TransactionHistoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyFilters();
  }

  void _applyFilters() {
    _filteredTransactions = widget.transactions.where((transaction) {
      // Filter by type
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'purchase' &&
            transaction.type != TransactionType.purchase) {
          return false;
        } else if (_selectedFilter == 'gift' &&
            transaction.type != TransactionType.giftSent &&
            transaction.type != TransactionType.giftReceived) {
          return false;
        } else if (_selectedFilter == 'reward' &&
            transaction.type != TransactionType.reward) {
          return false;
        }
      }

      // Filter by date range
      if (_selectedDateRange != null) {
        if (transaction.createdAt.isBefore(_selectedDateRange!.start) ||
            transaction.createdAt.isAfter(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            )) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4ECDC4),
              surface: Color(0xFF1D1E33),
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        _selectedDateRange = range;
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Purchases', 'purchase'),
                const SizedBox(width: 8),
                _buildFilterChip('Gifts', 'gift'),
                const SizedBox(width: 8),
                _buildFilterChip('Rewards', 'reward'),
                const SizedBox(width: 8),
                _buildDateFilterButton(),
              ],
            ),
          ),
        ),
        // Transaction list
        Expanded(
          child: widget.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF4ECDC4),
                    ),
                  ),
                )
              : _filteredTransactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 48,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions found',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => widget.onRefresh?.call(),
                      color: const Color(0xFF4ECDC4),
                      backgroundColor: const Color(0xFF1D1E33),
                      child: ListView.builder(
                        itemCount: _filteredTransactions.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final transaction = _filteredTransactions[index];
                          return _buildTransactionTile(context, transaction);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
          _applyFilters();
        });
      },
      backgroundColor: isSelected ? const Color(0xFF4ECDC4) : Colors.transparent,
      side: BorderSide(
        color: isSelected ? const Color(0xFF4ECDC4) : Colors.white24,
      ),
    );
  }

  Widget _buildDateFilterButton() {
    return GestureDetector(
      onTap: () => _selectDateRange(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedDateRange != null
                ? const Color(0xFF4ECDC4)
                : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 16,
              color: _selectedDateRange != null
                  ? const Color(0xFF4ECDC4)
                  : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              _selectedDateRange != null ? 'Custom' : 'Date',
              style: TextStyle(
                fontSize: 12,
                color: _selectedDateRange != null
                    ? Colors.white
                    : Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    TransactionModel transaction,
  ) {
    final (icon, label, color) = _getTransactionDisplay(transaction.type);
    final isIncome = transaction.type == TransactionType.giftReceived ||
        transaction.type == TransactionType.reward;
    final amountColor = isIncome ? Colors.green : Colors.white;
    final amountPrefix = isIncome ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(transaction.createdAt),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            if (transaction.description != null && transaction.description!.isNotEmpty)
              Text(
                transaction.description!,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$amountPrefix${transaction.amount} ${transaction.currency.value}',
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(transaction.status),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatStatus(transaction.status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showTransactionDetails(context, transaction),
      ),
    );
  }

  (IconData, String, Color) _getTransactionDisplay(TransactionType type) {
    switch (type) {
      case TransactionType.purchase:
        return (Icons.shopping_cart, 'Coin Purchase', Colors.blue);
      case TransactionType.giftSent:
        return (Icons.send, 'Gift Sent', Colors.orange);
      case TransactionType.giftReceived:
        return (Icons.card_giftcard, 'Gift Received', Colors.pink);
      case TransactionType.vipPurchase:
        return (Icons.diamond, 'VIP Badge', Colors.purple);
      case TransactionType.mvpPurchase:
        return (Icons.star, 'MVP Badge', Colors.amber);
      case TransactionType.guardianPurchase:
        return (Icons.shield, 'Guardian Badge', Colors.teal);
      case TransactionType.reward:
        return (Icons.card_giftcard, 'Reward', Colors.green);
      case TransactionType.refund:
        return (Icons.undo, 'Refund', Colors.yellow);
      case TransactionType.withdrawal:
        return (Icons.account_balance_wallet, 'Withdrawal', Colors.red);
      case TransactionType.adminAdjustment:
        return (Icons.admin_panel_settings, 'Admin Adjustment', Colors.grey);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  String _formatStatus(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green.withOpacity(0.3);
      case TransactionStatus.pending:
        return Colors.orange.withOpacity(0.3);
      case TransactionStatus.failed:
        return Colors.red.withOpacity(0.3);
      case TransactionStatus.cancelled:
        return Colors.grey.withOpacity(0.3);
    }
  }

  void _showTransactionDetails(
    BuildContext context,
    TransactionModel transaction,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D1E33),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transaction Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow('ID', transaction.id),
              _buildDetailRow('Type', transaction.type.value),
              _buildDetailRow('Amount', '${transaction.amount} ${transaction.currency.value}'),
              _buildDetailRow('Date', DateFormat('MMM dd, yyyy HH:mm').format(transaction.createdAt)),
              _buildDetailRow('Status', transaction.status.value),
              if (transaction.payment != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Payment Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildDetailRow('Method', transaction.payment!.method),
                if (transaction.payment!.transactionId != null)
                  _buildDetailRow('Transaction ID', transaction.payment!.transactionId!),
                if (transaction.payment!.currency != null)
                  _buildDetailRow('Currency', transaction.payment!.currency!),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
