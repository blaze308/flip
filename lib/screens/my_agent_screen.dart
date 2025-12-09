import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/agency_providers.dart';
import '../widgets/custom_toaster.dart';

/// My Agent Screen
/// Screen for users with an agent (hosts)
class MyAgentScreen extends ConsumerStatefulWidget {
  const MyAgentScreen({super.key});

  @override
  ConsumerState<MyAgentScreen> createState() => _MyAgentScreenState();
}

class _MyAgentScreenState extends ConsumerState<MyAgentScreen> {
  Future<void> _showLeaveAgencyDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Leave Agency',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to leave this agency? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ref.read(leaveAgencyProvider.notifier).leaveAgency();

      if (mounted) {
        if (result['success'] == true) {
          ToasterService.showSuccess(context, result['message'] ?? 'Left agency successfully');
          Navigator.pop(context); // Go back to agency screen
        } else {
          ToasterService.showError(context, result['message'] ?? 'Failed to leave agency');
        }
        ref.read(leaveAgencyProvider.notifier).reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membershipAsync = ref.watch(myAgencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'My Agent',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: membershipAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(myAgencyProvider.notifier).refresh(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (membership) {
          if (membership == null || !membership.isHost) {
            return const Center(
              child: Text(
                'You are not a host in any agency',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Agency Info Card
                Card(
                  color: const Color(0xFF1D1E33),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.business, color: Color(0xFF4ECDC4), size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    membership.agency?.name ?? 'Agency',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${membership.agency?.agencyId ?? "N/A"}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Role', membership.role.toUpperCase()),
                        _buildInfoRow('Status', membership.status.toUpperCase()),
                        if (membership.applicationStatus != 'approved')
                          _buildInfoRow('Application', membership.applicationStatus.toUpperCase()),
                        if (membership.assignedAgent != null)
                          _buildInfoRow(
                            'Assigned Agent',
                            membership.assignedAgent!['displayName'] ?? 'N/A',
                          ),
                        _buildInfoRow(
                          'Joined',
                          _formatDate(membership.joinedAt),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Performance Stats Card
                Card(
                  color: const Color(0xFF1D1E33),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Performance Stats',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Host Earnings', _formatCurrency(membership.hostEarnings)),
                        _buildInfoRow('Last Activity', membership.lastActivityAt != null
                            ? _formatDate(membership.lastActivityAt!)
                            : 'N/A'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Agent Contact Card
                if (membership.assignedAgent != null)
                  Card(
                    color: const Color(0xFF1D1E33),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Agent Contact',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (membership.assignedAgent != null && membership.assignedAgent!['photoURL'] != null)
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: NetworkImage(
                                    membership.assignedAgent!['photoURL'],
                                  ),
                                )
                              else
                                const CircleAvatar(
                                  radius: 24,
                                  child: Icon(Icons.person),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      membership.assignedAgent != null
                                          ? (membership.assignedAgent!['displayName'] ?? 'Agent')
                                          : 'Agent',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Your assigned agent',
                                      style: TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                // Leave Agency Button
                ref.watch(leaveAgencyProvider).when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                        ),
                      ),
                      error: (_, __) => ElevatedButton.icon(
                        onPressed: _showLeaveAgencyDialog,
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Leave Agency'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      data: (_) => ElevatedButton.icon(
                        onPressed: _showLeaveAgencyDialog,
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Leave Agency'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

