import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'services/token_auth_service.dart';
import 'services/user_service.dart';
import 'widgets/custom_toaster.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _websiteController = TextEditingController();
  final _occupationController = TextEditingController();

  File? _profileImage;
  File? _coverImage;
  bool _isSaving = false;

  // Interest tags
  final List<String> _allInterests = [
    '🎮 Gaming',
    '🎨 Art',
    '🎵 Music',
    '⚽ Sports',
    '🍔 Food',
    '✈️ Travel',
    '📚 Reading',
    '🎬 Movies',
    '💻 Tech',
    '🏋️ Fitness',
    '📸 Photography',
    '🌱 Nature',
    '🎭 Theater',
    '🎪 Comedy',
    '🔬 Science',
    '🎓 Education',
  ];

  final List<String> _selectedInterests = [];

  String? _currentPhotoURL;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    final currentUser = TokenAuthService.currentUser;
    if (currentUser != null) {
      setState(() {
        _currentPhotoURL = currentUser.photoURL;
      });
    }
  }

  double _calculateProgress() {
    int completed = 0;
    int total = 4; // Profile pic, bio, location, interests (3+)

    if (_profileImage != null || _currentPhotoURL != null) completed++;
    if (_bioController.text.trim().isNotEmpty) completed++;
    if (_locationController.text.trim().isNotEmpty) completed++;
    if (_selectedInterests.length >= 3) completed++;

    return completed / total;
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster('Failed to pick image');
      }
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _coverImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster('Failed to pick cover image');
      }
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _saveProfile() async {
    // Validate required fields
    if (!_formKey.currentState!.validate()) {
      context.showErrorToaster('Please fill in all required fields');
      return;
    }

    if (_selectedInterests.length < 3) {
      context.showErrorToaster('Please select at least 3 interests');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      print('📝 CompleteProfileScreen: Saving profile...');

      // Call the API to save profile data
      await UserService.completeProfile(
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        interests: _selectedInterests,
        profileImage: _profileImage,
        coverImage: _coverImage,
        website:
            _websiteController.text.trim().isNotEmpty
                ? _websiteController.text.trim()
                : null,
        occupation:
            _occupationController.text.trim().isNotEmpty
                ? _occupationController.text.trim()
                : null,
      );

      print('📝 CompleteProfileScreen: Profile saved successfully');

      if (mounted) {
        context.showSuccessToaster('Profile completed successfully!');
        // Navigate to biometric setup after completing profile
        Navigator.of(context).pushReplacementNamed('/biometric-setup');
      }
    } catch (e) {
      print('❌ CompleteProfileScreen: Error saving profile: $e');
      if (mounted) {
        context.showErrorToaster(
          'Failed to save profile. Please try again.',
          devMessage: 'Error: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _skipOptional() async {
    // Check if required fields are filled
    if (!_formKey.currentState!.validate()) {
      context.showErrorToaster('Please complete required fields first');
      return;
    }

    if (_selectedInterests.length < 3) {
      context.showErrorToaster('Please select at least 3 interests');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      print('📝 CompleteProfileScreen: Saving required fields only...');

      // Save only the required fields
      await UserService.completeProfile(
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        interests: _selectedInterests,
        profileImage: _profileImage,
        coverImage: null, // Skip cover image
        website: null, // Skip website
        occupation: null, // Skip occupation
      );

      print('📝 CompleteProfileScreen: Required fields saved successfully');

      if (mounted) {
        context.showSuccessToaster('Profile saved successfully!');
        // Skip optional details and go straight to biometric setup
        Navigator.of(context).pushReplacementNamed('/biometric-setup');
      }
    } catch (e) {
      print('❌ CompleteProfileScreen: Error saving required fields: $e');
      if (mounted) {
        context.showErrorToaster(
          'Failed to save profile. Please try again.',
          devMessage: 'Error: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _calculateProgress();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            _buildHeader(progress),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Required Section
                      _buildSectionTitle('Profile Basics', required: true),
                      const SizedBox(height: 20),
                      _buildProfileImagePicker(),
                      const SizedBox(height: 24),
                      _buildBioField(),
                      const SizedBox(height: 16),
                      _buildLocationField(),

                      const SizedBox(height: 32),

                      // Interests (Required)
                      _buildSectionTitle('Your Interests', required: true),
                      const SizedBox(height: 8),
                      Text(
                        'Pick at least 3 interests (${_selectedInterests.length}/3)',
                        style: TextStyle(
                          color:
                              _selectedInterests.length >= 3
                                  ? const Color(0xFF4ECDC4)
                                  : Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInterestTags(),

                      const SizedBox(height: 40),

                      // Optional Details
                      _buildSectionTitle('Additional Details', required: false),
                      const SizedBox(height: 20),
                      _buildOccupationField(),
                      const SizedBox(height: 16),
                      _buildCoverImagePicker(),
                      const SizedBox(height: 16),
                      _buildWebsiteField(),

                      const SizedBox(height: 60),

                      // Action buttons
                      _buildActionButtons(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete Your Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add optional details',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4ECDC4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF4ECDC4),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool required = true}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF4ECDC4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
            ),
            child: const Text(
              'Required',
              style: TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ] else ...[
          const SizedBox(width: 8),
          Text(
            '(Optional)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickProfileImage,
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2A2A2A),
                border: Border.all(color: const Color(0xFF4ECDC4), width: 3),
                image:
                    _profileImage != null
                        ? DecorationImage(
                          image: FileImage(_profileImage!),
                          fit: BoxFit.cover,
                        )
                        : _currentPhotoURL != null
                        ? DecorationImage(
                          image: NetworkImage(_currentPhotoURL!),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  _profileImage == null && _currentPhotoURL == null
                      ? const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white24,
                      )
                      : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF4ECDC4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _bioController,
          maxLines: 4,
          maxLength: 150,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Bio *',
            hintText: 'Coffee lover ☕ | Designer from LA | Dog parent 🐕',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
            labelStyle: const TextStyle(color: Color(0xFF4ECDC4)),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4ECDC4), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Bio is required';
            }
            if (value.trim().length < 10) {
              return 'Bio must be at least 10 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Text(
          '💡 Tell people what you\'re passionate about',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _locationController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Location *',
            hintText: 'e.g., New York, USA',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            labelStyle: const TextStyle(color: Color(0xFF4ECDC4)),
            prefixIcon: const Icon(Icons.location_on, color: Color(0xFF4ECDC4)),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4ECDC4), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Location is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Text(
          '📍 This helps connect you with people nearby',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInterestTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          _allInterests.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return GestureDetector(
              onTap: () => _toggleInterest(interest),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient:
                      isSelected
                          ? const LinearGradient(
                            colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                          )
                          : null,
                  color: isSelected ? null : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color:
                        isSelected
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  interest,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildOccupationField() {
    return TextFormField(
      controller: _occupationController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Occupation',
        hintText: 'e.g., Software Engineer, Student, Artist',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(
          Icons.work_outline,
          color: Colors.white.withOpacity(0.7),
        ),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4ECDC4), width: 2),
        ),
      ),
    );
  }

  Widget _buildCoverImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              image:
                  _coverImage != null
                      ? DecorationImage(
                        image: FileImage(_coverImage!),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                _coverImage == null
                    ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to add cover photo',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                    : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '🖼️ Add a cover photo to personalize your profile',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildWebsiteField() {
    return TextFormField(
      controller: _websiteController,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: 'Website / Portfolio',
        hintText: 'https://yoursite.com',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(Icons.link, color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4ECDC4), width: 2),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child:
                _isSaving
                    ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Save & Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isSaving ? null : _skipOptional,
          child: Text(
            'Skip for Now',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
