import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../services/audio_service.dart';
import '../screens/image_viewer_screen.dart';
import '../screens/video_player_screen.dart';
import 'waveform_animation.dart';
import 'swipeable_message_bubble.dart';

class ModernMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isFromCurrentUser;
  final VoidCallback? onLongPress;
  final Function(String)? onReactionTap;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onDelete;

  const ModernMessageBubble({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    this.onLongPress,
    this.onReactionTap,
    this.onReply,
    this.onForward,
    this.onDelete,
  });

  @override
  State<ModernMessageBubble> createState() => _ModernMessageBubbleState();
}

class _ModernMessageBubbleState extends State<ModernMessageBubble>
    with TickerProviderStateMixin {
  bool _isPlayingAudio = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  /// Check if text contains only emojis (for larger display)
  bool _isEmojiOnly(String text) {
    if (text.isEmpty) return false;

    // Remove all emojis and check if anything remains
    final emojiRegex = RegExp(
      r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
    );
    final textWithoutEmoji = text.replaceAll(emojiRegex, '').trim();

    // If nothing remains, it's emoji-only
    return textWithoutEmoji.isEmpty && text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return SwipeableMessageBubble(
      onReply: widget.onReply,
      onMore: _showMessageOptions,
      onArchive: widget.onForward, // Using forward callback for archive
      isFromCurrentUser: widget.isFromCurrentUser,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Row(
          mainAxisAlignment:
              widget.isFromCurrentUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Message bubble - simplified without avatar
            Flexible(
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _buildMessageContent(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions() {
    // Show WhatsApp-style bottom sheet with options
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1F2C34),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Options
                  _buildOptionItem(Icons.reply_rounded, 'Reply', () {
                    Navigator.pop(context);
                    widget.onReply?.call();
                  }),
                  _buildOptionItem(Icons.forward_rounded, 'Forward', () {
                    Navigator.pop(context);
                    widget.onForward?.call();
                  }),
                  _buildOptionItem(Icons.star_outline_rounded, 'Star', () {
                    Navigator.pop(context);
                    // TODO: Implement star
                  }),
                  _buildOptionItem(Icons.copy_rounded, 'Copy', () {
                    Navigator.pop(context);
                    if (widget.message.content != null) {
                      Clipboard.setData(
                        ClipboardData(text: widget.message.content!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                          backgroundColor: Color(0xFF128C7E),
                        ),
                      );
                    }
                  }),
                  _buildOptionItem(Icons.info_outline_rounded, 'Info', () {
                    Navigator.pop(context);
                    // TODO: Implement info
                  }),
                  _buildOptionItem(Icons.delete_outline_rounded, 'Delete', () {
                    Navigator.pop(context);
                    widget.onDelete?.call();
                  }, isDestructive: true),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildOptionItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : const Color(0xFFE9EDEF),
              size: 24,
            ),
            const SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.red : const Color(0xFFE9EDEF),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (widget.message.type) {
      case MessageType.text:
        return _buildTextMessage();
      case MessageType.image:
        return _buildImageMessage();
      case MessageType.video:
        return _buildVideoMessage();
      case MessageType.audio:
        return _buildAudioMessage();
      case MessageType.file:
        return _buildFileMessage();
      default:
        return _buildTextMessage();
    }
  }

  Widget _buildTextMessage() {
    // Check if message is emoji-only (for larger display)
    final content = widget.message.content ?? '';
    final isEmojiOnly = _isEmojiOnly(content);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
        minHeight: 40, // Ensure minimum height for visibility
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color:
            widget.isFromCurrentUser
                ? const Color(0xFF005C4B)
                : const Color(0xFF1F2C34),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft: Radius.circular(widget.isFromCurrentUser ? 8 : 0),
          bottomRight: Radius.circular(widget.isFromCurrentUser ? 0 : 8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: TextStyle(
              color: const Color(0xFFE9EDEF),
              fontSize: isEmojiOnly ? 32.0 : 14.5, // Larger size for emoji-only
              height: 1.35,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                widget.message.formattedTime,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
              if (widget.isFromCurrentUser) ...[
                const SizedBox(width: 4),
                _buildMessageStatus(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage() {
    // For optimistic UI: show local file if available
    final bool hasLocalFile = widget.message.localFilePath != null;
    final bool isSending = widget.message.status == MessageStatus.sending;

    if (!hasLocalFile && widget.message.media?.url == null)
      return _buildTextMessage();

    // Use media URL or local path for unique Hero tag to avoid duplicates
    final mediaIdentifier =
        widget.message.media?.url ??
        widget.message.localFilePath ??
        widget.message.id;
    final heroTag = 'image_$mediaIdentifier';

    return GestureDetector(
      onTap:
          hasLocalFile
              ? null
              : () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder:
                        (context, animation, secondaryAnimation) =>
                            ImageViewerScreen(
                              imageUrl: widget.message.media!.url,
                              heroTag: heroTag,
                            ),
                    transitionsBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                      child,
                    ) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
      child: Hero(
        tag: heroTag,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
            maxHeight: 300,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Show local file or network image
                if (hasLocalFile)
                  Image.file(
                    File(widget.message.localFilePath!),
                    fit: BoxFit.cover,
                  )
                else
                  Image.network(
                    widget.message.media!.url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF4ECDC4),
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                // Sending overlay for optimistic UI (no text, just visual indicator)
                if (isSending)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF4ECDC4),
                          ),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                // Zoom indicator (only for uploaded images)
                if (!hasLocalFile && !isSending)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage() {
    // For optimistic UI: show local file if available
    final bool hasLocalFile = widget.message.localFilePath != null;
    final bool isSending = widget.message.status == MessageStatus.sending;

    if (!hasLocalFile && widget.message.media?.url == null)
      return _buildTextMessage();

    // Use media URL or local path for unique Hero tag to avoid duplicates
    final mediaIdentifier =
        widget.message.media?.url ??
        widget.message.localFilePath ??
        widget.message.id;
    final heroTag = 'video_$mediaIdentifier';

    return GestureDetector(
      onTap:
          hasLocalFile
              ? null
              : () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder:
                        (context, animation, secondaryAnimation) =>
                            VideoPlayerScreen(
                              videoUrl: widget.message.media!.url,
                              heroTag: heroTag,
                            ),
                    transitionsBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                      child,
                    ) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
      child: Hero(
        tag: heroTag,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
            maxHeight: 300,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video thumbnail or placeholder
                if (hasLocalFile)
                  // Show placeholder for local video
                  Container(
                    height: 200,
                    color: const Color(0xFF2A2A2A),
                    child: const Center(
                      child: Icon(
                        Icons.videocam,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  )
                else if (widget.message.media!.thumbnailUrl != null &&
                    !widget.message.media!.thumbnailUrl!.contains('.mp4') &&
                    !widget.message.media!.thumbnailUrl!.contains('.mov') &&
                    !widget.message.media!.thumbnailUrl!.contains('.avi'))
                  Image.network(
                    widget.message.media!.thumbnailUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: const Color(0xFF2A2A2A),
                        child: const Center(
                          child: Icon(
                            Icons.videocam,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    height: 200,
                    color: const Color(0xFF2A2A2A),
                    child: const Center(
                      child: Icon(
                        Icons.videocam,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),

                // Uploading overlay for optimistic UI
                if (isSending)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF4ECDC4),
                            ),
                            strokeWidth: 2,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Play button overlay (only for uploaded videos)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),

                // Duration indicator
                if (widget.message.media!.duration != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.message.media!.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioMessage() {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            widget.isFromCurrentUser
                ? const Color(0xFF005C4B)
                : const Color(0xFF1F2C34),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft: Radius.circular(widget.isFromCurrentUser ? 8 : 0),
          bottomRight: Radius.circular(widget.isFromCurrentUser ? 0 : 8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button with modern design
          GestureDetector(
            onTap: _toggleAudioPlayback,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_isPlayingAudio ? 0.3 : 0.2),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isPlayingAudio
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey(_isPlayingAudio),
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Animated waveform or static bars
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Use animated waveform during playback
                SizedBox(
                  height: 32,
                  child:
                      _isPlayingAudio
                          ? WaveformAnimation(
                            isRecording: true,
                            color: Colors.white,
                            height: 32,
                            barCount: 25,
                          )
                          : _buildStaticWaveform(),
                ),
                const SizedBox(height: 6),
                // Duration with modern styling
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.message.media?.formattedDuration ?? '0:00',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStaticWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(25, (index) {
        // Create varied heights for visual interest
        final heights = [0.3, 0.5, 0.7, 0.9, 0.6, 0.4, 0.8, 0.5];
        final heightFactor = heights[index % heights.length];

        return Container(
          width: 3,
          height: 32 * heightFactor,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildFileMessage() {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient:
            widget.isFromCurrentUser
                ? const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                )
                : null,
        color: widget.isFromCurrentUser ? null : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.insert_drive_file,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.message.media?.fileName ?? 'File',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.message.media?.formattedFileSize ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatus() {
    switch (widget.message.status) {
      case MessageStatus.sent:
        return Icon(Icons.done, color: Colors.white.withOpacity(0.5), size: 14);
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          color: Colors.white.withOpacity(0.5),
          size: 14,
        );
      case MessageStatus.read:
        return const Icon(Icons.done_all, color: Color(0xFF53BDEB), size: 14);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, color: Colors.red, size: 14);
      case MessageStatus.sending:
        return Icon(
          Icons.access_time,
          color: Colors.white.withOpacity(0.5),
          size: 13,
        );
    }
  }

  Future<void> _toggleAudioPlayback() async {
    if (widget.message.media?.url == null) {
      print('❌ Audio playback: No media URL');
      return;
    }

    try {
      print(
        '🔊 Audio playback: Toggling playback for ${widget.message.media!.url}',
      );

      if (_isPlayingAudio) {
        print('🔊 Audio playback: Stopping audio');
        await AudioService.stopAudio();
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
        }
      } else {
        print('🔊 Audio playback: Starting audio');
        final success = await AudioService.playAudio(widget.message.media!.url);
        print('🔊 Audio playback: Play result: $success');

        if (success && mounted) {
          setState(() {
            _isPlayingAudio = true;
          });

          // Listen for audio completion
          AudioService.player.onPlayerComplete.listen((_) {
            print('🔊 Audio playback: Audio completed');
            if (mounted) {
              setState(() {
                _isPlayingAudio = false;
              });
            }
          });
        } else if (!success) {
          print('❌ Audio playback: Failed to play audio');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to play audio'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error playing audio: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
