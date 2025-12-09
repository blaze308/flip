import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_toaster.dart';

/// Contact Us Screen
/// Support contact form and live chat
class ContactUsScreen extends ConsumerStatefulWidget {
  const ContactUsScreen({super.key});

  @override
  ConsumerState<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends ConsumerState<ContactUsScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedCategory = 'General';

  final List<String> _categories = [
    'General',
    'Technical Issue',
    'Payment Issue',
    'Account Issue',
    'Report Abuse',
    'Feature Request',
    'Other',
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitContact() async {
    if (_subjectController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ToasterService.showError(context, 'Please fill in all fields');
      return;
    }

    // TODO: Implement contact submission API
    ToasterService.showSuccess(context, 'Message sent successfully! We\'ll get back to you soon.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Contact Us',
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
            // Contact Info
            Card(
              color: const Color(0xFF1D1E33),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Get in Touch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildContactItem(Icons.email, 'support@flip.com'),
                    _buildContactItem(Icons.phone, '+1 (555) 123-4567'),
                    _buildContactItem(Icons.access_time, 'Mon-Fri, 9AM-6PM EST'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Contact Form
            Card(
              color: const Color(0xFF1D1E33),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Send us a Message',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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

                    // Subject
                    TextField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        labelText: 'Subject',
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
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),

                    // Message
                    TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: 'Message',
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
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 6,
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    ElevatedButton.icon(
                      onPressed: _submitContact,
                      icon: const Icon(Icons.send),
                      label: const Text('Send Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Live Chat
            Card(
              color: const Color(0xFF1D1E33),
              child: ListTile(
                leading: const Icon(Icons.chat, color: Color(0xFF4ECDC4)),
                title: const Text('Live Chat', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Chat with our support team',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                onTap: () {
                  ToasterService.showInfo(context, 'Live chat feature coming soon');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4ECDC4), size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

