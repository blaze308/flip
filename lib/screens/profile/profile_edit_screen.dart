import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/user_model.dart';
import '../../services/profile_service.dart';
import '../../services/user_service.dart';
import '../../providers/profile_providers.dart';
import '../../widgets/custom_toaster.dart';
import '../../utils/validators.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:async';
import 'social_links_screen.dart';

/// Profile Edit Screen - Edit user profile information
class ProfileEditScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const ProfileEditScreen({super.key, required this.user});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _websiteController;
  late TextEditingController _occupationController;
  late TextEditingController _countryController;
  late TextEditingController _cityController;

  String? _selectedGender;
  List<String> _interests = [];
  bool _isLoading = false;
  File? _profileImage;
  File? _coverImage;

  bool _isUsernameValidating = false;
  bool? _isUsernameAvailable;
  Timer? _debounceTimer;
  String? _usernameError;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.user.displayName,
    );
    _usernameController = TextEditingController(text: widget.user.username);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _websiteController = TextEditingController(text: widget.user.website ?? '');
    _occupationController = TextEditingController(
      text: widget.user.occupation ?? '',
    );
    _countryController = TextEditingController(text: widget.user.country ?? '');
    _cityController = TextEditingController(text: widget.user.city ?? '');
    _selectedGender = widget.user.gender;
    _interests = List.from(widget.user.interests ?? []);

    _usernameController.addListener(_onUsernameChanged);
    _displayNameController.addListener(_markChanged);
    _usernameController.addListener(_markChanged);
    _bioController.addListener(_markChanged);
    _websiteController.addListener(_markChanged);
    _occupationController.addListener(_markChanged);
    _countryController.addListener(_markChanged);
    _cityController.addListener(_markChanged);
  }

  void _markChanged() {
    if (mounted && !_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _onUsernameChanged() {
    final username = _usernameController.text;

    // Don't check if it's the same as current
    if (username == widget.user.username) {
      if (mounted) {
        setState(() {
          _isUsernameAvailable = null;
          _isUsernameValidating = false;
          _usernameError = null;
        });
      }
      return;
    }

    // Basic local validation first
    final localError = Validators.username(username);
    if (localError != null) {
      if (mounted) {
        setState(() {
          _usernameError = localError;
          _isUsernameAvailable = false;
          _isUsernameValidating = false;
        });
      }
      return;
    }

    // Debounce backend check
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      setState(() {
        _isUsernameValidating = true;
        _usernameError = null;
      });

      final isAvailable = await ProfileService.checkUsernameAvailability(
        username,
      );

      if (!mounted) return;

      setState(() {
        _isUsernameAvailable = isAvailable;
        _isUsernameValidating = false;
        if (!isAvailable) {
          _usernameError = 'This username is already taken';
        }
      });
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _occupationController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfile) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      // Crop image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio:
            isProfile
                ? const CropAspectRatio(ratioX: 1, ratioY: 1) // 1:1 for profile
                : const CropAspectRatio(
                  ratioX: 16,
                  ratioY: 9,
                ), // 16:9 for cover
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isProfile ? 'Crop Profile Photo' : 'Crop Cover Photo',
            toolbarColor: const Color(0xFF1D1E33),
            toolbarWidgetColor: Colors.white,
            initAspectRatio:
                isProfile
                    ? CropAspectRatioPreset.square
                    : CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: isProfile ? 'Crop Profile Photo' : 'Crop Cover Photo',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _hasChanges = true;
          if (isProfile) {
            _profileImage = File(croppedFile.path);
          } else {
            _coverImage = File(croppedFile.path);
          }
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? profileImageUrl;
      String? coverImageUrl;

      // Upload profile image if changed
      if (_profileImage != null) {
        profileImageUrl = await UserService.uploadImage(_profileImage!);
      }

      // Upload cover image if changed
      if (_coverImage != null) {
        coverImageUrl = await UserService.uploadImage(_coverImage!);
      }

      // Update profile
      final result = await ProfileService.updateProfile(
        displayName: _displayNameController.text,
        bio: _bioController.text,
        website:
            _websiteController.text.isEmpty ? null : _websiteController.text,
        occupation:
            _occupationController.text.isEmpty
                ? null
                : _occupationController.text,
        country:
            _countryController.text.isEmpty ? null : _countryController.text,
        city: _cityController.text.isEmpty ? null : _cityController.text,
        gender: _selectedGender,
        interests: _interests.isEmpty ? null : _interests,
        photoURL: profileImageUrl,
        coverPhotoURL: coverImageUrl,
      );

      // Update username separately if changed
      if (_usernameController.text != widget.user.username) {
        final usernameResult = await ProfileService.updateUsername(
          _usernameController.text,
        );
        if (usernameResult['success'] != true) {
          if (mounted) {
            ToasterService.showError(
              context,
              usernameResult['message'] ?? 'Failed to update username',
            );
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success'] == true) {
          // Refresh profile provider
          ref.read(profileProvider(null).notifier).refresh();

          ToasterService.showSuccess(context, 'Profile updated successfully');
          Navigator.pop(context, true);
        } else {
          ToasterService.showError(
            context,
            result['message'] ?? 'Failed to update profile',
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

  Future<void> _handleBack() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            title: const Text(
              'Unsaved Changes',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'You have unsaved changes. Are you sure you want to discard them?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Discard',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldPop == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1D1E33),
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _handleBack(),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4ECDC4),
                        ),
                      )
                      : const Text(
                        'Save',
                        style: TextStyle(
                          color: Color(0xFF4ECDC4),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCoverImageSection(),
              const SizedBox(height: 16),
              _buildProfileImageSection(),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _displayNameController,
                label: 'Display Name',
                hint: 'Your display name',
                validator: Validators.displayName,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _usernameController,
                label: 'Username',
                hint: 'Your unique username',
                errorText: _usernameError,
                suffix:
                    _isUsernameValidating
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF4ECDC4),
                          ),
                        )
                        : _isUsernameAvailable == true
                        ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        )
                        : _isUsernameAvailable == false
                        ? const Icon(Icons.error, color: Colors.red, size: 20)
                        : null,
                validator: Validators.username,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _bioController,
                label: 'Bio',
                hint: 'Tell us about yourself',
                maxLines: 4,
                maxLength: 150,
                validator: (v) => Validators.bio(v, maxLength: 150),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _websiteController,
                label: 'Website',
                hint: 'https://yourwebsite.com',
                validator: Validators.url,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _occupationController,
                label: 'Occupation',
                hint: 'What do you do?',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _countryController,
                label: 'Country',
                hint: 'Your country',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _cityController,
                label: 'City',
                hint: 'Your city',
              ),
              const SizedBox(height: 16),
              _buildGenderDropdown(),
              const SizedBox(height: 16),
              _buildSettingsTile(
                icon: Icons.link,
                title: 'Social Links',
                subtitle: 'Link TikTok, Instagram, and more',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SocialLinksScreen(user: widget.user),
                    ),
                  );
                  if (result == true) {
                    setState(() => _hasChanges = true);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildInterestsSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImageSection() {
    return GestureDetector(
      onTap: () => _pickImage(false),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_coverImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_coverImage!, fit: BoxFit.cover),
              )
            else if (widget.user.coverPhotoURL != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: widget.user.coverPhotoURL!,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
                  ),
                ),
              ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: GestureDetector(
        onTap: () => _pickImage(true),
        child: Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF4ECDC4),
              backgroundImage:
                  _profileImage != null
                      ? FileImage(_profileImage!)
                      : (widget.user.profileImageUrl != null
                              ? CachedNetworkImageProvider(
                                widget.user.profileImageUrl!,
                              )
                              : null)
                          as ImageProvider?,
              child:
                  _profileImage == null && widget.user.profileImageUrl == null
                      ? Text(
                        widget.user.initials,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                      : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF4ECDC4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    String? errorText,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            errorText: errorText,
            suffixIcon:
                suffix != null
                    ? Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: suffix,
                    )
                    : null,
            filled: true,
            fillColor: const Color(0xFF1D1E33),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          dropdownColor: const Color(0xFF1D1E33),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1D1E33),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
            DropdownMenuItem(
              value: 'prefer_not_to_say',
              child: Text('Prefer not to say'),
            ),
          ],
          onChanged: (value) {
            setState(() => _selectedGender = value);
          },
        ),
      ],
    );
  }

  Widget _buildInterestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Interests',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton.icon(
              onPressed: _addInterest,
              icon: const Icon(Icons.add, color: Color(0xFF4ECDC4)),
              label: const Text(
                'Add',
                style: TextStyle(color: Color(0xFF4ECDC4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _interests.map((interest) {
                return Chip(
                  label: Text(interest),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() => _interests.remove(interest));
                  },
                  backgroundColor: const Color(0xFF1D1E33),
                  labelStyle: const TextStyle(color: Colors.white),
                  deleteIconColor: Colors.grey,
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF4ECDC4), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _addInterest() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          title: const Text(
            'Add Interest',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter interest',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() => _interests.add(controller.text));
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Add',
                style: TextStyle(color: Color(0xFF4ECDC4)),
              ),
            ),
          ],
        );
      },
    );
  }
}
