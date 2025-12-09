import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/custom_toaster.dart';

/// Feedback Screen
/// Submit feedback to improve the app
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedType = 'Suggestion';
  String _selectedCategory = 'General';

  final List<String> _types = [
    'Suggestion',
    'Bug Report',
    'Feature Request',
    'Compliment',
    'Complaint',
    'Other',
  ];

  final List<String> _categories = [
    'General',
    'User Interface',
    'Performance',
    'Live Streaming',
    'Messaging',
    'Payments',
    'Agency System',
    'Premium Features',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_messageController.text.trim().isEmpty) {
      ToasterService.showError(context, 'Please enter your feedback');
      return;
    }

    final result = await ref.read(feedbackProvider.notifier).submitFeedback(
          type: _selectedType,
          message: _messageController.text.trim(),
          category: _selectedCategory,
        );

    if (mounted) {
      if (result['success'] == true) {
        ToasterService.showSuccess(context, result['message'] ?? 'Feedback submitted successfully');
        Navigator.pop(context);
      } else {
        ToasterService.showError(context, result['message'] ?? 'Failed to submit feedback');
      }
      ref.read(feedbackProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Feedback',
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
                      'Share Your Feedback',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'We value your input! Help us improve by sharing your thoughts, suggestions, or reporting issues.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // Type Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Feedback Type',
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

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
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
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Message
                    TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: 'Your Feedback',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Tell us what you think...',
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
                      maxLines: 8,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ref.watch(feedbackProvider).when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                            ),
                          ),
                          error: (_, __) => ElevatedButton.icon(
                            onPressed: _submitFeedback,
                            icon: const Icon(Icons.send),
                            label: const Text('Submit Feedback'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4ECDC4),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          data: (_) => ElevatedButton.icon(
                            onPressed: _submitFeedback,
                            icon: const Icon(Icons.send),
                            label: const Text('Submit Feedback'),
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
            const SizedBox(height: 16),

            // My Feedback
            Card(
              color: const Color(0xFF1D1E33),
              child: ListTile(
                leading: const Icon(Icons.history, color: Color(0xFF4ECDC4)),
                title: const Text('My Feedback', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'View your submitted feedback',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                onTap: () {
                  ToasterService.showInfo(context, 'My feedback feature coming soon');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

