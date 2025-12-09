import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Official Services Screen
/// Agency support and services
class OfficialServicesScreen extends ConsumerWidget {
  const OfficialServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Official Services',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent, size: 64, color: Colors.white30),
            const SizedBox(height: 16),
            const Text(
              'Official Services',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agency support and services coming soon',
              style: TextStyle(color: Colors.white30, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

