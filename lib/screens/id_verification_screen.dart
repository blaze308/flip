import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/custom_toaster.dart';

/// ID Verification Screen
/// Upload and verify identity documents
class IDVerificationScreen extends ConsumerStatefulWidget {
  const IDVerificationScreen({super.key});

  @override
  ConsumerState<IDVerificationScreen> createState() => _IDVerificationScreenState();
}

class _IDVerificationScreenState extends ConsumerState<IDVerificationScreen> {
  String _selectedDocType = 'Passport';

  final List<String> _docTypes = [
    'Passport',
    'National ID',
    'Driver\'s License',
    'Residence Permit',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'ID Verification',
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
                      Icons.badge,
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
                      'Upload a valid government-issued ID to verify your identity and get a verified badge.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Document Type Selection
            _buildSectionHeader('Select Document Type'),
            Card(
              color: const Color(0xFF1D1E33),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  value: _selectedDocType,
                  decoration: InputDecoration(
                    labelText: 'Document Type',
                    labelStyle: const TextStyle(color: Colors.white70),
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
                  ),
                  dropdownColor: const Color(0xFF1D1E33),
                  style: const TextStyle(color: Colors.white),
                  items: _docTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedDocType = value;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Upload Instructions
            _buildSectionHeader('Upload Instructions'),
            _buildInstructionItem('Take a clear photo of your document'),
            _buildInstructionItem('Ensure all text is readable'),
            _buildInstructionItem('No glare or shadows'),
            _buildInstructionItem('Document must be valid (not expired)'),
            _buildInstructionItem('Upload both front and back (if applicable)'),
            const SizedBox(height: 24),

            // Upload Buttons
            _buildSectionHeader('Upload Documents'),
            _buildUploadButton(
              'Front Side',
              Icons.upload_file,
              () {
                ToasterService.showInfo(context, 'Document upload feature coming soon');
              },
            ),
            const SizedBox(height: 12),
            _buildUploadButton(
              'Back Side (if applicable)',
              Icons.upload_file,
              () {
                ToasterService.showInfo(context, 'Document upload feature coming soon');
              },
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton.icon(
              onPressed: () {
                ToasterService.showInfo(context, 'ID verification feature coming soon');
              },
              icon: const Icon(Icons.send),
              label: const Text('Submit for Verification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Privacy Notice
            Card(
              color: const Color(0xFF1D1E33),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock, color: Color(0xFF4ECDC4), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: const Text(
                        'Your documents are encrypted and securely stored. We will never share your personal information.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildInstructionItem(String instruction) {
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
                instruction,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton(String label, IconData icon, VoidCallback onTap) {
    return Card(
      color: const Color(0xFF1D1E33),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4ECDC4)),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        onTap: onTap,
      ),
    );
  }
}

