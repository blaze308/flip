import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/invitation_providers.dart';

/// Invitation History Screen
/// Track invitations and rewards
class InvitationHistoryScreen extends ConsumerWidget {
  const InvitationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(invitationHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Invitation History',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: historyAsync.when(
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
            ],
          ),
        ),
        data: (history) {
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: Colors.white30),
                  const SizedBox(height: 16),
                  const Text(
                    'No invitation history yet',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start inviting friends to see your history here',
                    style: TextStyle(color: Colors.white30, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final invitation = history[index];
              return Card(
                color: const Color(0xFF1D1E33),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.person_add, color: Color(0xFF4ECDC4)),
                  title: Text(
                    invitation['friendName'] ?? 'Friend',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    invitation['date'] ?? 'Unknown date',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: Text(
                    '+${invitation['reward'] ?? 0} coins',
                    style: const TextStyle(
                      color: Color(0xFF4ECDC4),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

