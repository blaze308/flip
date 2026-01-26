import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/profile_service.dart';
import '../../widgets/custom_toaster.dart';
import '../../utils/validators.dart';

class SocialLinksScreen extends StatefulWidget {
  final UserModel user;

  const SocialLinksScreen({super.key, required this.user});

  @override
  State<SocialLinksScreen> createState() => _SocialLinksScreenState();
}

class _SocialLinksScreenState extends State<SocialLinksScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _instagramController;
  late TextEditingController _tiktokController;
  late TextEditingController _twitterController;
  late TextEditingController _youtubeController;
  late TextEditingController _websiteController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final social = widget.user.socialLinks ?? {};
    _instagramController = TextEditingController(
      text: social['instagram'] ?? '',
    );
    _tiktokController = TextEditingController(text: social['tiktok'] ?? '');
    _twitterController = TextEditingController(text: social['twitter'] ?? '');
    _youtubeController = TextEditingController(text: social['youtube'] ?? '');
    _websiteController = TextEditingController(text: widget.user.website ?? '');
  }

  @override
  void dispose() {
    _instagramController.dispose();
    _tiktokController.dispose();
    _twitterController.dispose();
    _youtubeController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _saveLinks() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ProfileService.updateProfile(
        website:
            _websiteController.text.isEmpty ? null : _websiteController.text,
        socialLinks: {
          'instagram': _instagramController.text,
          'tiktok': _tiktokController.text,
          'twitter': _twitterController.text,
          'youtube': _youtubeController.text,
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success'] == true) {
          ToasterService.showSuccess(context, 'Social links updated');
          Navigator.pop(context, true);
        } else {
          ToasterService.showError(
            context,
            result['message'] ?? 'Failed to update links',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToasterService.showError(context, 'An error occurred: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Social Links',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveLinks,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text(
                      'Save',
                      style: TextStyle(
                        color: Color(0xFF4ECDC4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Add your social media profiles to your Flip profile to help others find you.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildSocialField(
              controller: _instagramController,
              label: 'Instagram',
              hint: '@username',
              iconPath: 'assets/svg/instagram.svg', // Placeholder usage
              icon: Icons.camera_alt_outlined,
              prefix: 'instagram.com/',
            ),
            const SizedBox(height: 16),
            _buildSocialField(
              controller: _tiktokController,
              label: 'TikTok',
              hint: '@username',
              icon: Icons.music_note_outlined,
              prefix: 'tiktok.com/@',
            ),
            const SizedBox(height: 16),
            _buildSocialField(
              controller: _twitterController,
              label: 'Twitter / X',
              hint: '@username',
              icon: Icons.close,
              prefix: 'x.com/',
            ),
            const SizedBox(height: 16),
            _buildSocialField(
              controller: _youtubeController,
              label: 'YouTube',
              hint: 'channel_id',
              icon: Icons.play_circle_outline,
              prefix: 'youtube.com/',
            ),
            const SizedBox(height: 16),
            _buildSocialField(
              controller: _websiteController,
              label: 'Website',
              hint: 'https://yourwebsite.com',
              icon: Icons.link,
              validator: Validators.url,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    String? iconPath,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixText: prefix,
            prefixStyle: const TextStyle(color: Color(0xFF4ECDC4)),
            prefixIcon: Icon(icon, color: Colors.white70, size: 20),
            filled: true,
            fillColor: const Color(0xFF161B22),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
            ),
          ),
        ),
      ],
    );
  }
}
