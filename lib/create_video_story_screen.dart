import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'services/story_service.dart';
import 'models/story_model.dart';
import 'widgets/custom_toaster.dart';
import 'widgets/loading_button.dart';

class CreateVideoStoryScreen extends StatefulWidget {
  const CreateVideoStoryScreen({Key? key}) : super(key: key);

  @override
  State<CreateVideoStoryScreen> createState() => _CreateVideoStoryScreenState();
}

class _CreateVideoStoryScreenState extends State<CreateVideoStoryScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedVideo;
  bool _isLoading = false;

  // Privacy settings
  StoryPrivacyType _privacy = StoryPrivacyType.public;
  bool _allowReplies = true;
  bool _allowReactions = true;
  bool _allowScreenshot = true;

  @override
  void initState() {
    super.initState();
    // Show dialog after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showVideoSourceDialog();
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _showVideoSourceDialog() async {
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Select Video Source',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.videocam,
                        title: 'Record',
                        onTap:
                            () => Navigator.of(context).pop(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.video_library,
                        title: 'Gallery',
                        onTap:
                            () =>
                                Navigator.of(context).pop(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );

    if (result != null) {
      await _pickVideo(result);
    } else {
      // User cancelled, go back
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration:
            source == ImageSource.camera
                ? const Duration(minutes: 1)
                : null, // Only limit recording, not selection
      );

      if (video != null) {
        // For gallery videos, we need to validate duration manually
        if (source == ImageSource.gallery) {
          // Note: Video duration validation would require additional packages like video_player
          // For now, we'll accept all gallery videos and let the backend handle validation
          context.showInfoToaster(
            'Note: Please ensure your video is under 1 minute for optimal story experience',
          );
        }

        setState(() {
          _selectedVideo = File(video.path);
        });
      } else {
        // User cancelled video selection
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster('Failed to pick video: $e');
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _createStory() async {
    if (_selectedVideo == null) {
      context.showErrorToaster('Please select a video');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🎥 Creating video story with file: ${_selectedVideo!.path}');
      print('🎥 File size: ${await _selectedVideo!.length()} bytes');
      print('🎥 File exists: ${await _selectedVideo!.exists()}');
      print('🎥 Media type: ${StoryMediaType.video.name}');
      print('🎥 Privacy: ${_privacy.name}');

      final result = await StoryService.createMediaStory(
        mediaFile: _selectedVideo!,
        mediaType: StoryMediaType.video,
        caption: _captionController.text.trim(),
        privacy: _privacy,
        allowReplies: _allowReplies,
        allowReactions: _allowReactions,
        allowScreenshot: _allowScreenshot,
      );

      print('🎥 Video story creation result: ${result.success}');
      if (!result.success) {
        print('🎥 Error message: ${result.message}');
      }

      if (result.success && mounted) {
        context.showSuccessToaster('Video story created successfully!');
        Navigator.of(context).pop();
        Navigator.of(context).pop(); // Go back to home screen
      } else if (mounted) {
        context.showErrorToaster(result.message);
      }
    } catch (e) {
      print('🎥 Video story creation exception: $e');
      if (mounted) {
        context.showErrorToaster('Failed to create story: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          'Video Story',
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
                _selectedVideo != null && !_isLoading ? _createStory : null,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Share',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ],
      ),
      body: _selectedVideo == null ? _buildEmptyState() : _buildVideoPreview(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_outlined, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No video selected',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Record or select a video',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showVideoSourceDialog,
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Select Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Column(
      children: [
        // Video preview placeholder
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[900],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Video Preview',
                        style: TextStyle(color: Colors.grey[400], fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Video selected: ${_selectedVideo!.path.split('/').last}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Change video button
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _showVideoSourceDialog,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Caption input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add a caption',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                maxLines: 3,
                maxLength: 200,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write a caption...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[300],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Videos are limited to 1 minute for stories',
                        style: TextStyle(
                          color: Colors.orange[300],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4ECDC4), size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
