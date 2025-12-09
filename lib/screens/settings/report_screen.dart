import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/custom_toaster.dart';

/// Report Screen
/// Report users or content
class ReportScreen extends ConsumerStatefulWidget {
  final String? targetId;
  final String? targetType; // 'user', 'post', 'message', etc.

  const ReportScreen({
    super.key,
    this.targetId,
    this.targetType,
  });

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedReason = 'Spam';
  String _selectedType = 'User';

  final List<String> _reasons = [
    'Spam',
    'Harassment',
    'Inappropriate Content',
    'Fake Account',
    'Scam or Fraud',
    'Violence',
    'Hate Speech',
    'Copyright Violation',
    'Other',
  ];

  final List<String> _types = [
    'User',
    'Post',
    'Message',
    'Live Stream',
    'Comment',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.targetType != null) {
      _selectedType = widget.targetType!;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.trim().isEmpty) {
      ToasterService.showError(context, 'Please provide a description');
      return;
    }

    final result = await ref.read(reportProvider.notifier).reportContent(
          type: _selectedType.toLowerCase(),
          targetId: widget.targetId ?? 'unknown',
          reason: _selectedReason,
          description: _descriptionController.text.trim(),
        );

    if (mounted) {
      if (result['success'] == true) {
        ToasterService.showSuccess(context, result['message'] ?? 'Report submitted successfully');
        Navigator.pop(context);
      } else {
        ToasterService.showError(context, result['message'] ?? 'Failed to submit report');
      }
      ref.read(reportProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Report',
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Submit a Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Help us keep the community safe by reporting inappropriate content or behavior.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // Type Dropdown
                    if (widget.targetType == null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedType,
                            decoration: InputDecoration(
                              labelText: 'What are you reporting?',
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
                            items: _types.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedType = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // Reason Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedReason,
                      decoration: InputDecoration(
                        labelText: 'Reason',
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
                      items: _reasons.map((reason) {
                        return DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedReason = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Please provide details about the issue...',
                        hintStyle: const TextStyle(color: Colors.white30),
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
                      maxLines: 6,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ref.watch(reportProvider).when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                            ),
                          ),
                          error: (_, __) => ElevatedButton.icon(
                            onPressed: _submitReport,
                            icon: const Icon(Icons.send),
                            label: const Text('Submit Report'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          data: (_) => ElevatedButton.icon(
                            onPressed: _submitReport,
                            icon: const Icon(Icons.send),
                            label: const Text('Submit Report'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
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
      ),
    );
  }
}

