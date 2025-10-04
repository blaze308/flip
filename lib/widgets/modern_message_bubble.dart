import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../services/audio_service.dart';
import '../screens/image_viewer_screen.dart';
import '../screens/video_player_screen.dart';

class ModernMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isFromCurrentUser;
  final VoidCallback? onLongPress;
  final Function(String)? onReactionTap;

  const ModernMessageBubble({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    this.onLongPress,
    this.onReactionTap,
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

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Column(
        crossAxisAlignment:
            widget.isFromCurrentUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          // Sender name (for group chats)
          if (!widget.isFromCurrentUser)
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 4),
              child: Text(
                widget.message.senderName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Message bubble
          Row(
            mainAxisAlignment:
                widget.isFromCurrentUser
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!widget.isFromCurrentUser) ...[
                _buildAvatar(),
                const SizedBox(width: 8),
              ],

              Flexible(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: GestureDetector(
                        onTapDown: _onTapDown,
                        onTapUp: _onTapUp,
                        onTapCancel: _onTapCancel,
                        onLongPress: widget.onLongPress,
                        child: _buildMessageContent(),
                      ),
                    );
                  },
                ),
              ),

              if (widget.isFromCurrentUser) ...[
                const SizedBox(width: 8),
                _buildAvatar(),
              ],
            ],
          ),

          // Message time and status
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: widget.isFromCurrentUser ? 0 : 48,
              right: widget.isFromCurrentUser ? 48 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.message.formattedTime,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                if (widget.isFromCurrentUser) ...[
                  const SizedBox(width: 4),
                  _buildMessageStatus(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
        ),
      ),
      child:
          widget.message.senderAvatar != null
              ? ClipOval(
                child: Image.network(
                  widget.message.senderAvatar!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => _buildDefaultAvatar(),
                ),
              )
              : _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        widget.message.senderName.isNotEmpty
            ? widget.message.senderName[0].toUpperCase()
            : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
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
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Text(
        widget.message.content ?? '',
        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
      ),
    );
  }

  Widget _buildImageMessage() {
    if (widget.message.media?.url == null) return _buildTextMessage();

    final heroTag = 'image_${widget.message.id}';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => ImageViewerScreen(
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
                // Zoom indicator
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.zoom_in, color: Colors.white, size: 16),
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
    if (widget.message.media?.url == null) return _buildTextMessage();

    final heroTag = 'video_${widget.message.id}';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => VideoPlayerScreen(
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
                // Video thumbnail
                widget.message.media!.thumbnailUrl != null &&
                        !widget.message.media!.thumbnailUrl!.contains('.mp4') &&
                        !widget.message.media!.thumbnailUrl!.contains('.mov') &&
                        !widget.message.media!.thumbnailUrl!.contains('.avi')
                    ? Image.network(
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
                    : Container(
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

                // Play button overlay
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
          GestureDetector(
            onTap: _toggleAudioPlayback,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isPlayingAudio ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Audio waveform placeholder
                Container(
                  height: 20,
                  child: Row(
                    children: List.generate(20, (index) {
                      return Container(
                        width: 2,
                        height: (index % 4 + 1) * 5.0,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.message.media?.formattedDuration ?? '0:00',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
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
        return const Icon(Icons.check, color: Colors.white54, size: 16);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, color: Colors.white54, size: 16);
      case MessageStatus.read:
        return const Icon(Icons.done_all, color: Color(0xFF4ECDC4), size: 16);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, color: Colors.red, size: 16);
      case MessageStatus.sending:
        // Show single check (optimistic UI) - like WhatsApp/Instagram
        return const Icon(Icons.access_time, color: Colors.white38, size: 14);
    }
  }

  Future<void> _toggleAudioPlayback() async {
    if (widget.message.media?.url == null) return;

    try {
      if (_isPlayingAudio) {
        await AudioService.stopAudio();
        setState(() {
          _isPlayingAudio = false;
        });
      } else {
        final success = await AudioService.playAudio(widget.message.media!.url);
        if (success) {
          setState(() {
            _isPlayingAudio = true;
          });

          // Listen for audio completion
          AudioService.player.onPlayerComplete.listen((_) {
            if (mounted) {
              setState(() {
                _isPlayingAudio = false;
              });
            }
          });
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }
}
