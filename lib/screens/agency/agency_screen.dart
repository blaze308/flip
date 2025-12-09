import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/agency_providers.dart';
import '../../widgets/custom_toaster.dart';
import 'agent_screen.dart';
import 'my_agent_screen.dart';

/// Agency Screen
/// Main screen for joining or creating an agency
class AgencyScreen extends ConsumerStatefulWidget {
  const AgencyScreen({super.key});

  @override
  ConsumerState<AgencyScreen> createState() => _AgencyScreenState();
}

class _AgencyScreenState extends ConsumerState<AgencyScreen> {
  final TextEditingController _agencyIdController = TextEditingController();

  @override
  void dispose() {
    _agencyIdController.dispose();
    super.dispose();
  }

  void _navigateToRoleScreen() {
    final membershipAsync = ref.read(myAgencyProvider);
    membershipAsync.whenData((membership) {
      if (membership == null) {
        // No agency membership
        return;
      }

      if (membership.isOwner || membership.isAgent) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AgentScreen()),
        );
      } else if (membership.isHost) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyAgentScreen()),
        );
      }
    });
  }

  Future<void> _joinAgency() async {
    if (_agencyIdController.text.trim().isEmpty) {
      ToasterService.showError(context, 'Please enter an agency ID');
      return;
    }

    final result = await ref.read(joinAgencyProvider.notifier).joinAgency(
          agencyId: _agencyIdController.text.trim(),
        );

    if (mounted) {
      if (result['success'] == true) {
        ToasterService.showSuccess(context, result['message'] ?? 'Application submitted successfully');
        _agencyIdController.clear();
        ref.read(myAgencyProvider.notifier).refresh();
        // Navigate to appropriate screen based on role
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToRoleScreen();
        });
      } else {
        ToasterService.showError(context, result['message'] ?? 'Failed to join agency');
      }
      ref.read(joinAgencyProvider.notifier).reset();
    }
  }

  Future<void> _createAgency() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Create Agency',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Agency Name',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final createResult = await ref.read(createAgencyProvider.notifier).createAgency(
            name: nameController.text.trim(),
            description: descriptionController.text.trim(),
          );

      if (mounted) {
        if (createResult['success'] == true) {
          ToasterService.showSuccess(context, createResult['message'] ?? 'Agency created successfully');
          ref.read(myAgencyProvider.notifier).refresh();
          // Navigate to agent screen
          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AgentScreen()),
            );
          });
        } else {
          ToasterService.showError(context, createResult['message'] ?? 'Failed to create agency');
        }
        ref.read(createAgencyProvider.notifier).reset();
      }
    }

    nameController.dispose();
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membershipAsync = ref.watch(myAgencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Agency System',
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
          if (membership != null) {
            // User is already in an agency
            return _buildAlreadyMemberView(membership);
          }

          // User is not in an agency
          return _buildJoinAgencyView();
        },
      ),
    );
  }

  Widget _buildAlreadyMemberView(membership) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (membership.isOwner || membership.isAgent) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AgentScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyAgentScreen()),
                );
              }
            },
            icon: const Icon(Icons.dashboard),
            label: Text(membership.isOwner || membership.isAgent
                ? 'Go to Agent Dashboard'
                : 'View My Agent'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinAgencyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Benefits Card
          Card(
            color: const Color(0xFF1D1E33),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star, color: Color(0xFF4ECDC4)),
                      SizedBox(width: 8),
                      Text(
                        'Agency Benefits',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBenefitItem('12% commission on host earnings'),
                  _buildBenefitItem('Recruit sub-agents'),
                  _buildBenefitItem('Manage hosts'),
                  _buildBenefitItem('Track earnings and performance'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Rules Card
          Card(
            color: const Color(0xFF1D1E33),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.rule, color: Color(0xFF4ECDC4)),
                      SizedBox(width: 8),
                      Text(
                        'Agency Rules',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRuleItem('Maintain active status'),
                  _buildRuleItem('Support your hosts'),
                  _buildRuleItem('Follow platform guidelines'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Join Agency Section
          Card(
            color: const Color(0xFF1D1E33),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Join an Agency',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _agencyIdController,
                    decoration: InputDecoration(
                      labelText: 'Enter Agency ID',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'e.g., AG123456',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.business, color: Color(0xFF4ECDC4)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ref.watch(joinAgencyProvider).when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                        ),
                        error: (_, __) => ElevatedButton.icon(
                          onPressed: _joinAgency,
                          icon: const Icon(Icons.group_add),
                          label: const Text('Join Agency'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ECDC4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        data: (_) => ElevatedButton.icon(
                          onPressed: _joinAgency,
                          icon: const Icon(Icons.group_add),
                          label: const Text('Join Agency'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ECDC4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Create Agency Section
          Card(
            color: const Color(0xFF1D1E33),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Your Own Agency',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Become an agency owner and start recruiting agents and hosts',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ref.watch(createAgencyProvider).when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                        ),
                        error: (_, __) => ElevatedButton.icon(
                          onPressed: _createAgency,
                          icon: const Icon(Icons.add_business),
                          label: const Text('Create Agency'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ECDC4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        data: (_) => ElevatedButton.icon(
                          onPressed: _createAgency,
                          icon: const Icon(Icons.add_business),
                          label: const Text('Create Agency'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ECDC4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
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

  Widget _buildBenefitItem(String benefit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4ECDC4), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              benefit,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rule,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

