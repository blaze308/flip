import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/post_service.dart';
import '../../services/event_bus.dart';
import '../../models/post_model.dart';
import '../../widgets/custom_toaster.dart';

class CreateImagePostScreen extends StatefulWidget {
  const CreateImagePostScreen({Key? key}) : super(key: key);

  @override
  State<CreateImagePostScreen> createState() => _CreateImagePostScreenState();
}

class _CreateImagePostScreenState extends State<CreateImagePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isPublic = true;
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Photo Post',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed:
                _isLoading || _selectedImages.isEmpty ? null : _createPost,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      'Post',
                      style: TextStyle(
                        color:
                            _selectedImages.isEmpty
                                ? Colors.grey
                                : const Color(0xFF4ECDC4),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image preview area
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[800]!, width: 2),
              ),
              child:
                  _selectedImages.isEmpty
                      ? _buildImagePlaceholder()
                      : _buildImagePreview(),
            ),
          ),

          // Caption and options
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Caption input
                      const Text(
                        'Caption',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _captionController,
                        maxLines: 3,
                        maxLength: 2000,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write a caption...',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          counterStyle: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Clear all button (only show if multiple images)
                      if (_selectedImages.length > 1) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _clearImages,
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear All Images'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Privacy setting
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Public Post',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch(
                            value: _isPublic,
                            activeColor: const Color(0xFF4ECDC4),
                            onChanged: (value) {
                              setState(() => _isPublic = value);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey[600]!,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Tap to select photos',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You can select multiple photos',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        // Main image display
        PageView.builder(
          itemCount: _selectedImages.length,
          onPageChanged: (index) {
            setState(() => _currentImageIndex = index);
          },
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                _selectedImages[index],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            );
          },
        ),

        // Image counter
        if (_selectedImages.length > 1)
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${_selectedImages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

        // Delete button
        Positioned(
          top: 15,
          left: 15,
          child: GestureDetector(
            onTap: () => _removeImage(_currentImageIndex),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete, color: Colors.white, size: 20),
            ),
          ),
        ),

        // Add more images button (hide when max reached)
        if (_selectedImages.length < 10)
          Positioned(
            bottom: 15,
            right: 15,
            child: GestureDetector(
              onTap: _addMoreImages,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          ),

        // Page indicators
        if (_selectedImages.length > 1)
          Positioned(
            bottom: 15,
            left: 0,
            right:
                _selectedImages.length < 10
                    ? 70
                    : 15, // Make space for the add button when visible
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _selectedImages.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        index == _currentImageIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images.map((image) => File(image.path)).toList();
          _currentImageIndex = 0;
        });
      }
    } catch (e) {
      ToasterService.showError(
        context,
        'Failed to pick images: ${e.toString()}',
      );
    }
  }

  Future<void> _addMoreImages() async {
    try {
      // Check if we've reached the maximum limit
      const maxImages = 10;
      if (_selectedImages.length >= maxImages) {
        ToasterService.showError(
          context,
          'Maximum $maxImages images allowed per post',
        );
        return;
      }

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (images.isNotEmpty) {
        final remainingSlots = maxImages - _selectedImages.length;
        final imagesToAdd = images.take(remainingSlots).toList();

        setState(() {
          _selectedImages.addAll(imagesToAdd.map((image) => File(image.path)));
        });

        if (images.length > remainingSlots) {
          ToasterService.showError(
            context,
            'Only $remainingSlots more images could be added (max $maxImages total)',
          );
        }
      }
    } catch (e) {
      ToasterService.showError(
        context,
        'Failed to add more images: ${e.toString()}',
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_currentImageIndex >= _selectedImages.length &&
          _selectedImages.isNotEmpty) {
        _currentImageIndex = _selectedImages.length - 1;
      } else if (_selectedImages.isEmpty) {
        _currentImageIndex = 0;
      }
    });
  }

  void _clearImages() {
    setState(() {
      _selectedImages.clear();
      _currentImageIndex = 0;
    });
  }

  Future<void> _createPost() async {
    if (_selectedImages.isEmpty) {
      ToasterService.showError(context, 'Please select at least one image');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload images to Cloudinary via backend
      print('📸 Uploading ${_selectedImages.length} images to Cloudinary...');
      final List<String> imageUrls;

      if (_selectedImages.length == 1) {
        // Single image upload
        final imageUrl = await PostService.uploadImage(_selectedImages[0]);
        imageUrls = [imageUrl];
      } else {
        // Multiple images upload
        imageUrls = await PostService.uploadMultipleImages(_selectedImages);
      }

      print('📸 All images uploaded successfully to Cloudinary: $imageUrls');

      final createdPost = await PostService.createPost(
        type: PostType.image,
        content:
            _captionController.text.trim().isNotEmpty
                ? _captionController.text.trim()
                : null,
        imageUrls: imageUrls,
        isPublic: _isPublic,
      );

      if (mounted) {
        ToasterService.showSuccess(context, 'Photo post created successfully!');

        // Fire event to notify home screen
        EventBus().fire(
          PostCreatedEvent(postId: createdPost.id, postType: 'image'),
        );

        // Navigate back to home
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ToasterService.showError(
          context,
          'Failed to create post: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
