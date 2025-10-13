import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// WhatsApp-style modern video preview
class ModernVideoPreview extends StatefulWidget {
  final File videoFile;
  final Function(File, String) onSend; // onSend(file, caption)
  final VoidCallback onCancel;
  final String? recipientName; // Optional recipient name

  const ModernVideoPreview({
    super.key,
    required this.videoFile,
    required this.onSend,
    required this.onCancel,
    this.recipientName,
  });

  @override
  State<ModernVideoPreview> createState() => _ModernVideoPreviewState();
}

class _ModernVideoPreviewState extends State<ModernVideoPreview> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _isPlaying = false;
  String _caption = '';
  final TextEditingController _captionController = TextEditingController();
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller!.initialize();

      setState(() {
        _isLoading = false;
      });

      // Add listener for when video ends
      _controller!.addListener(() {
        if (_controller!.value.position >= _controller!.value.duration) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        }
      });
    } catch (e) {
      print('Error initializing video: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_controller == null) return;

    setState(() {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  void _toggleMute() {
    if (_controller == null) return;

    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _handleSend() {
    widget.onSend(widget.videoFile, _caption);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatFileSize() {
    final bytes = widget.videoFile.lengthSync();
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF25D366),
                    ),
                  ),
                )
                : Stack(
                  children: [
                    // Video player
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),

                    // Top bar with close button and tools
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            // Close button (X)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: widget.onCancel,
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ),

                            const Spacer(),

                            // Mute/Unmute button
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: _toggleMute,
                                icon: Icon(
                                  _isMuted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ),

                            // Video duration and size
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_formatDuration(_controller!.value.duration)} · ${_formatFileSize()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // GIF button (placeholder)
                            Container(
                              margin: const EdgeInsets.only(right: 8, left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'GIF',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Play/Pause button in center
                    if (!_isPlaying)
                      Center(
                        child: GestureDetector(
                          onTap: _togglePlayback,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _togglePlayback,
                          child: Container(color: Colors.transparent),
                        ),
                      ),

                    // Bottom bar with recipient name, caption, and send button
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.85),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Recipient name (if provided)
                            if (widget.recipientName != null)
                              Container(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  top: 16,
                                  bottom: 8,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.recipientName!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                            // Caption input and send button
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Gallery icon (left side)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        // TODO: Open gallery for more videos
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Gallery feature coming soon!',
                                            ),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.photo_library_outlined,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Caption text field
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: TextField(
                                        controller: _captionController,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Add a caption...',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            fontSize: 16,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 12,
                                              ),
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Camera icon
                                              IconButton(
                                                onPressed: () {
                                                  // TODO: Switch to video recording
                                                },
                                                icon: Icon(
                                                  Icons.videocam_rounded,
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                  size: 20,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        ),
                                        maxLines: 4,
                                        minLines: 1,
                                        onChanged: (value) {
                                          setState(() {
                                            _caption = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Send button
                                  GestureDetector(
                                    onTap: _handleSend,
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF25D366),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
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
