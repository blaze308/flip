import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/gamification_service.dart';

class SubscriptionHistoryScreen extends StatefulWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  State<SubscriptionHistoryScreen> createState() =>
      _SubscriptionHistoryScreenState();
}

class _SubscriptionHistoryScreenState extends State<SubscriptionHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _subscriptions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final history = await GamificationService.getSubscriptions();
      setState(() {
        _subscriptions = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F101C),
      appBar: AppBar(
        title: const Text('Subscription History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        _fetchHistory();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _subscriptions.isEmpty
              ? const Center(
                child: Text(
                  'No subscription history found',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _subscriptions.length,
                itemBuilder: (context, index) {
                  final sub = _subscriptions[index];
                  return _buildSubscriptionItem(sub);
                },
              ),
    );
  }

  Widget _buildSubscriptionItem(Map<String, dynamic> sub) {
    final type = sub['type'] ?? 'subscription';
    final tier = sub['tier'] ?? '';
    final status = sub['status'] ?? 'active';
    final startDate = DateTime.parse(sub['startDate']);
    final endDate = DateTime.parse(sub['endDate']);
    final paymentMethod = sub['paymentMethod'] ?? 'unknown';

    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'expired':
        statusColor = Colors.orange;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.white60;
    }

    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${type.toString().toUpperCase()} ${tier.isNotEmpty ? "- ${tier.toString().toUpperCase()}" : ""}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toString().toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Start Date',
              DateFormat('MMM dd, yyyy').format(startDate),
            ),
            _buildInfoRow(
              'End Date',
              DateFormat('MMM dd, yyyy').format(endDate),
            ),
            _buildInfoRow(
              'Payment',
              paymentMethod.toString().replaceAll('_', ' '),
            ),
            if (sub['targetUserId'] != null)
              _buildInfoRow(
                'Target',
                sub['targetUserId']['displayName'] ?? 'User',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
