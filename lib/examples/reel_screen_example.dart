import 'package:flutter/material.dart';
import '../services/share_service.dart';
import '../services/video_downloader_service.dart';
import '../widgets/video_download_progress.dart';
import '../widgets/custom_toaster.dart';

/// Example implementation of a reel screen with sharing and downloading
class ReelScreenExample extends StatefulWidget {
  final String reelId;
  final String videoUrl;
  final String authorName;
  final String caption;
  final String thumbnailUrl;

  const ReelScreenExample({
    super.key,
    required this.reelId,
    required this.videoUrl,
    required this.authorName,
    required this.caption,
    required this.thumbnailUrl,
  });

  @override
  State<ReelScreenExample> createState() => _ReelScreenExampleState();
}

class _ReelScreenExampleState extends State<ReelScreenExample> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _showSuccessIndicator = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player would go here
          Center(
            child: Container(
              color: Colors.grey[900],
              child: const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Overlay UI
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                // Share button
                _buildActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: _handleShare,
                ),
                const SizedBox(height: 24),

                // Download button
                _buildActionButton(
                  icon: _isDownloading ? Icons.downloading : Icons.download,
                  label: _isDownloading ? 'Downloading' : 'Save',
                  onTap: _isDownloading ? null : _handleDownload,
                ),
              ],
            ),
          ),

          // Download progress indicator (TikTok-style)
          if (_isDownloading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: VideoDownloadProgress(
                progress: _downloadProgress,
                onCancel: () {
                  setState(() {
                    _isDownloading = false;
                    _downloadProgress = 0.0;
                  });
                },
              ),
            ),

          // Success indicator
          if (_showSuccessIndicator)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: DownloadSuccessIndicator(
                  onDismiss: () {
                    setState(() {
                      _showSuccessIndicator = false;
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShare() async {
    try {
      await ShareService.shareReel(
        reelId: widget.reelId,
        authorName: widget.authorName,
        caption: widget.caption,
        thumbnailUrl: widget.thumbnailUrl,
        context: context,
      );

      if (mounted) {
        context.showSuccessToaster('Reel shared successfully!');
      }
    } catch (e) {
      print('❌ Error sharing reel: $e');
      if (mounted) {
        context.showErrorToaster('Failed to share reel');
      }
    }
  }

  Future<void> _handleDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final fileName = 'flip_reel_${widget.reelId}.mp4';

      final result = await VideoDownloaderService.downloadVideo(
        videoUrl: widget.videoUrl,
        fileName: fileName,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (result.success) {
        setState(() {
          _showSuccessIndicator = true;
        });

        if (mounted) {
          context.showSuccessToaster('Video saved to gallery!');
        }
      } else {
        if (mounted) {
          context.showErrorToaster(
            result.message,
            devMessage: 'Download failed: ${result.message}',
          );
        }
      }
    } catch (e) {
      print('❌ Error downloading video: $e');
      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        context.showErrorToaster(
          'Failed to download video',
          devMessage: 'Error: $e',
        );
      }
    }
  }
}

/// Example for post sharing
class PostShareExample extends StatelessWidget {
  final String postId;
  final String authorName;
  final String content;
  final String? imageUrl;

  const PostShareExample({
    super.key,
    required this.postId,
    required this.authorName,
    required this.content,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      onPressed: () => _handleShare(context),
    );
  }

  Future<void> _handleShare(BuildContext context) async {
    try {
      await ShareService.sharePost(
        postId: postId,
        authorName: authorName,
        content: content,
        imageUrl: imageUrl,
        context: context,
      );

      if (context.mounted) {
        context.showSuccessToaster('Post shared successfully!');
      }
    } catch (e) {
      print('❌ Error sharing post: $e');
      if (context.mounted) {
        context.showErrorToaster('Failed to share post');
      }
    }
  }
}

/// Example for profile sharing
class ProfileShareExample extends StatelessWidget {
  final String userId;
  final String username;
  final String? displayName;
  final String? bio;

  const ProfileShareExample({
    super.key,
    required this.userId,
    required this.username,
    this.displayName,
    this.bio,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      onPressed: () => _handleShare(context),
    );
  }

  Future<void> _handleShare(BuildContext context) async {
    try {
      await ShareService.shareProfile(
        userId: userId,
        username: username,
        displayName: displayName,
        bio: bio,
      );

      if (context.mounted) {
        context.showSuccessToaster('Profile shared successfully!');
      }
    } catch (e) {
      print('❌ Error sharing profile: $e');
      if (context.mounted) {
        context.showErrorToaster('Failed to share profile');
      }
    }
  }
}
