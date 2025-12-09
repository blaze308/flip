import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../providers/profile_providers.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/purchase_dialog_v2.dart';
import '../../widgets/transfer_dialog.dart';

/// Wallet Screen with Riverpod
/// Displays balance, transaction history, and purchase/transfer options
class WalletScreenRiverpod extends ConsumerStatefulWidget {
  const WalletScreenRiverpod({super.key});

  @override
  ConsumerState<WalletScreenRiverpod> createState() =>
      _WalletScreenRiverpodState();
}

class _WalletScreenRiverpodState extends ConsumerState<WalletScreenRiverpod>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTransactionType = 'all'; // 'all', 'coins', 'diamonds'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedTransactionType = 'all';
            break;
          case 1:
            _selectedTransactionType = 'coins';
            break;
          case 2:
            _selectedTransactionType = 'diamonds';
            break;
        }
      });
      // Refresh transactions when tab changes
      ref.read(transactionsProvider.notifier).refresh();
    }
  }

  Future<void> _loadWalletData() async {
    ref.read(walletBalanceProvider.notifier).refresh();
    ref.read(transactionsProvider.notifier).refresh();
  }

  Future<void> _showPurchaseDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const PurchaseDialogV2(),
    );

    if (result == true) {
      ref.read(walletBalanceProvider.notifier).refresh();
      ref.read(transactionsProvider.notifier).refresh();
    }
  }

  Future<void> _showTransferDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const TransferDialog(),
    );

    if (result == true) {
      ref.read(walletBalanceProvider.notifier).refresh();
      ref.read(transactionsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('My Wallet', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadWalletData,
        color: const Color(0xFF4ECDC4),
        backgroundColor: const Color(0xFF1D1E33),
        child: CustomScrollView(
          slivers: [
            // Balance Card
            SliverToBoxAdapter(child: _buildBalanceCard()),

            // Action Buttons
            SliverToBoxAdapter(child: _buildActionButtons()),

            // Tabs
            SliverToBoxAdapter(child: _buildTransactionTabs()),

            // Transaction List
            _buildTransactionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final balanceAsync = ref.watch(walletBalanceProvider);

    return balanceAsync.when(
      loading:
          () => Container(
            margin: const EdgeInsets.all(16),
            height: 150,
            child: ShimmerLoading(
              width: double.infinity,
              height: 150,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
      error:
          (error, stack) => Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Failed to load balance',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
      data:
          (balance) => Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBalanceItem('🪙', 'Coins', balance['coins'] ?? 0),
                    _buildBalanceItem(
                      '💎',
                      'Diamonds',
                      balance['diamonds'] ?? 0,
                    ),
                    _buildBalanceItem('⭐', 'Points', balance['points'] ?? 0),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildBalanceItem(String icon, String label, int value) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 4),
        Text(
          NumberFormat('#,###').format(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showPurchaseDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Buy Coins'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showTransferDialog,
              icon: const Icon(Icons.send),
              label: const Text('Transfer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4ECDC4),
                side: const BorderSide(color: Color(0xFF4ECDC4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF4ECDC4),
        labelColor: const Color(0xFF4ECDC4),
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Coins'),
          Tab(text: 'Diamonds'),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    final transactionsAsync = ref.watch(transactionsProvider);

    return transactionsAsync.when(
      loading:
          () => SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ShimmerLoading(
                  width: double.infinity,
                  height: 80,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              childCount: 5,
            ),
          ),
      error:
          (error, stack) => SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load transactions',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(color: Colors.grey[400], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your transaction history will appear here',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final transaction = transactions[index];
            return _buildTransactionItem(transaction);
          }, childCount: transactions.length),
        );
      },
    );
  }

  Widget _buildTransactionItem(TransactionModel transaction) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(transaction.colorValue).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              transaction.typeIcon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.type.toString().split('.').last.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (transaction.description != null)
                  Text(
                    transaction.description!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  DateFormat(
                    'MMM dd, yyyy • hh:mm a',
                  ).format(transaction.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.amount > 0 ? '+' : ''}${transaction.formattedAmount}',
                style: TextStyle(
                  color: transaction.amount > 0 ? Colors.green : Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                transaction.currency.toString().split('.').last.toUpperCase(),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
