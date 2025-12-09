import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/custom_toaster.dart';

/// Face Authentication Screen
/// Verify identity using facial recognition
class FaceAuthenticationScreen extends ConsumerWidget {
  const FaceAuthenticationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Face Authentication',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF1D1E33),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.face,
                      size: 80,
                      color: Color(0xFF4ECDC4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Verify Your Identity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use facial recognition to verify your identity and increase your account security.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Benefits
            _buildSectionHeader('Benefits'),
            _buildBenefitItem('Enhanced account security'),
            _buildBenefitItem('Faster login process'),
            _buildBenefitItem('Verified badge on profile'),
            _buildBenefitItem('Access to premium features'),
            _buildBenefitItem('Increased trust from community'),
            const SizedBox(height: 24),

            // Requirements
            _buildSectionHeader('Requirements'),
            _buildRequirementItem('Good lighting'),
            _buildRequirementItem('Clear face visibility'),
            _buildRequirementItem('Remove glasses (if possible)'),
            _buildRequirementItem('Look directly at camera'),
            const SizedBox(height: 24),

            // Start Button
            ElevatedButton.icon(
              onPressed: () {
                ToasterService.showInfo(context, 'Face authentication feature coming soon');
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Start Verification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF4ECDC4),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String benefit) {
    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4ECDC4), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                benefit,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String requirement) {
    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                requirement,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

