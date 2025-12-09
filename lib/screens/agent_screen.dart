import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/agency_providers.dart';
import '../widgets/custom_toaster.dart';

/// Agent Screen
/// Dashboard for agents/owners managing hosts
class AgentScreen extends ConsumerStatefulWidget {
  const AgentScreen({super.key});

  @override
  ConsumerState<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends ConsumerState<AgentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membershipAsync = ref.watch(myAgencyProvider);
    final statsAsync = ref.watch(agencyStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Agent Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4ECDC4),
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFF4ECDC4),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Hosts'),
            Tab(text: 'Agents'),
            Tab(text: 'Reports'),
          ],
        ),
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
          if (membership == null || (!membership.isOwner && !membership.isAgent)) {
            return const Center(
              child: Text(
                'You are not an agent or owner',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(membership, statsAsync),
              _buildHostsTab(membership),
              _buildAgentsTab(membership),
              _buildReportsTab(membership),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(membership, statsAsync) {
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
                  _buildInfoRow('Commission Rate', '${membership.agency?.commissionRate ?? 12.0}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Stats Cards
          statsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) {
              if (stats == null) return const SizedBox.shrink();

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Invited Agents',
                          '${stats['invitedAgentsCount'] ?? membership.invitedAgentsCount}',
                          Icons.people,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Hosts',
                          '${stats['hostsCount'] ?? membership.hostsCount}',
                          Icons.person,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Earnings',
                          _formatCurrency(stats['totalEarnings'] ?? membership.totalEarnings),
                          Icons.attach_money,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'My Commission',
                          _formatCurrency(stats['totalCommission'] ?? membership.totalCommission),
                          Icons.account_balance_wallet,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Add Host',
            Icons.person_add,
            () {
              // TODO: Navigate to Add Host Screen
              ToasterService.showInfo(context, 'Add Host feature coming soon');
            },
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            'Invite Agent',
            Icons.person_add_alt_1,
            () {
              // TODO: Navigate to Invite Agent Screen
              ToasterService.showInfo(context, 'Invite Agent feature coming soon');
            },
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            'Coins Trading',
            Icons.currency_exchange,
            () {
              // TODO: Navigate to Coins Trading Screen
              ToasterService.showInfo(context, 'Coins Trading feature coming soon');
            },
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            'Official Services',
            Icons.support_agent,
            () {
              // TODO: Navigate to Official Services Screen
              ToasterService.showInfo(context, 'Official Services feature coming soon');
            },
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            'Invitation Report',
            Icons.assignment,
            () {
              // TODO: Navigate to Invitation Report Screen
              ToasterService.showInfo(context, 'Invitation Report feature coming soon');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHostsTab(membership) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 64, color: Colors.white30),
          const SizedBox(height: 16),
          const Text(
            'Host Management',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Host applications and management coming soon',
            style: TextStyle(color: Colors.white30, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAgentsTab(membership) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people, size: 64, color: Colors.white30),
          const SizedBox(height: 16),
          const Text(
            'Agent Management',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agent rankings and management coming soon',
            style: TextStyle(color: Colors.white30, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab(membership) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assessment, size: 64, color: Colors.white30),
          const SizedBox(height: 16),
          const Text(
            'Reports & Analytics',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Detailed reports coming soon',
            style: TextStyle(color: Colors.white30, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
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

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      color: const Color(0xFF1D1E33),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF4ECDC4), size: 24),
            const SizedBox(height: 8),
            Text(
              value,
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
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return Card(
      color: const Color(0xFF1D1E33),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4ECDC4)),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        onTap: onPressed,
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
}

