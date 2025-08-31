import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';
import 'services/post_service.dart';
import 'services/event_bus.dart';
import 'models/post_model.dart';
import 'widgets/custom_toaster.dart';

class CreateVideoPostScreen extends StatefulWidget {
  const CreateVideoPostScreen({Key? key}) : super(key: key);

  @override
  State<CreateVideoPostScreen> createState() => _CreateVideoPostScreenState();
}

class _CreateVideoPostScreenState extends State<CreateVideoPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedVideo;
  File? _thumbnailImage;
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  bool _isPublic = true;
  Duration _videoDuration = Duration.zero;
  bool _isPlaying = false;

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
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
          'Create Video Post',
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
                _isLoading || _selectedVideo == null ? null : _createPost,
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
                            _selectedVideo == null
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
          // Video preview area
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[800]!, width: 2),
              ),
              child:
                  _selectedVideo == null
                      ? _buildVideoPlaceholder()
                      : _buildVideoPreview(),
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
                      const SizedBox(height: 20),

                      // Video info
                      if (_selectedVideo != null) ...[
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.videocam,
                                    color: Color(0xFF4ECDC4),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Video Duration:',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDuration(_videoDuration),
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _selectThumbnail,
                                      icon: const Icon(Icons.image, size: 18),
                                      label: Text(
                                        _thumbnailImage == null
                                            ? 'Select Thumbnail'
                                            : 'Change Thumbnail',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[800],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _clearVideo,
                                      icon: const Icon(Icons.clear, size: 18),
                                      label: const Text('Clear Video'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildVideoPlaceholder() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickVideo,
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
                    Icons.videocam_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tap to select video',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose from gallery or record new',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickVideo(fromCamera: false),
                icon: const Icon(Icons.video_library),
                label: const Text('Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickVideo(fromCamera: true),
                icon: const Icon(Icons.videocam),
                label: const Text('Record'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    return Stack(
      children: [
        // Video player or thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[900],
            child:
                _videoController != null &&
                        _videoController!.value.isInitialized
                    ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                    : _thumbnailImage != null
                    ? Image.file(
                      _thumbnailImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                    : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Video Preview',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formatDuration(_videoDuration),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
          ),
        ),

        // Play/Pause button overlay
        Positioned.fill(
          child: Center(
            child: GestureDetector(
              onTap: _toggleVideoPlayback,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ),

        // Duration badge
        Positioned(
          bottom: 15,
          right: 15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatDuration(_videoDuration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickVideo({bool fromCamera = false}) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 10), // 10 minute limit
      );

      if (video != null) {
        final videoFile = File(video.path);

        // Initialize video player to get actual duration
        final controller = VideoPlayerController.file(videoFile);
        await controller.initialize();

        // Generate thumbnail from video
        final thumbnailData = await VideoThumbnail.thumbnailData(
          video: video.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 800,
          maxHeight: 600,
          quality: 80,
        );

        File? thumbnailFile;
        if (thumbnailData != null) {
          // Save thumbnail to temporary file
          final tempDir = Directory.systemTemp;
          final thumbnailPath =
              '${tempDir.path}/video_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
          thumbnailFile = File(thumbnailPath);
          await thumbnailFile.writeAsBytes(thumbnailData);
        }

        setState(() {
          _selectedVideo = videoFile;
          _videoController?.dispose(); // Dispose previous controller
          _videoController = controller;
          _videoDuration = controller.value.duration;
          _thumbnailImage = thumbnailFile;
          _isPlaying = false;
        });
      }
    } catch (e) {
      ToasterService.showError(
        context,
        'Failed to pick video: ${e.toString()}',
      );
    }
  }

  Future<void> _selectThumbnail() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _thumbnailImage = File(image.path);
        });
      }
    } catch (e) {
      ToasterService.showError(
        context,
        'Failed to select thumbnail: ${e.toString()}',
      );
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      setState(() {
        if (_isPlaying) {
          _videoController!.pause();
          _isPlaying = false;
        } else {
          _videoController!.play();
          _isPlaying = true;
        }
      });
    }
  }

  void _clearVideo() {
    setState(() {
      _videoController?.dispose();
      _videoController = null;
      _selectedVideo = null;
      _thumbnailImage = null;
      _videoDuration = Duration.zero;
      _isPlaying = false;
    });
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '0:00';

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '$minutes:${twoDigits(seconds)}';
  }

  Future<void> _createPost() async {
    if (_selectedVideo == null) {
      ToasterService.showError(context, 'Please select a video');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload video to Cloudinary via backend
      print('🎥 Uploading video to Cloudinary...');
      final videoUploadResult = await PostService.uploadVideo(_selectedVideo!);

      final String videoUrl = videoUploadResult['videoUrl'] as String;
      String thumbnailUrl = videoUploadResult['thumbnailUrl'] as String;
      final double duration = videoUploadResult['duration'] as double;

      // If user selected a custom thumbnail, upload it separately
      if (_thumbnailImage != null) {
        print('📸 Uploading custom thumbnail...');
        thumbnailUrl = await PostService.uploadImage(_thumbnailImage!);
      }

      print('🎥 Video uploaded successfully: $videoUrl');
      print('📸 Thumbnail URL: $thumbnailUrl');

      final createdPost = await PostService.createPost(
        type: PostType.video,
        content:
            _captionController.text.trim().isNotEmpty
                ? _captionController.text.trim()
                : null,
        videoUrl: videoUrl,
        videoThumbnail: thumbnailUrl,
        videoDuration: Duration(seconds: duration.round()),
        isPublic: _isPublic,
      );

      if (mounted) {
        ToasterService.showSuccess(context, 'Video post created successfully!');

        // Fire event to notify home screen
        EventBus().fire(
          PostCreatedEvent(postId: createdPost.id, postType: 'video'),
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
