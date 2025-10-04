import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../services/audio_service.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isFromCurrentUser;
  final VoidCallback? onLongPress;
  final Function(String)? onReactionTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    this.onLongPress,
    this.onReactionTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isPlayingAudio = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment:
              widget.isFromCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
          children: [
            // Message bubble
            Row(
              mainAxisAlignment:
                  widget.isFromCurrentUser
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
              children: [
                if (!widget.isFromCurrentUser) ...[
                  _buildAvatar(),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          widget.isFromCurrentUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      children: [
                        // Sender name (for group chats and non-current user)
                        if (!widget.isFromCurrentUser &&
                            widget.message.senderName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              widget.message.senderName,
                              style: const TextStyle(
                                color: Color(0xFF4ECDC4),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        // Reply preview (if replying to another message)
                        if (widget.message.replyTo != null)
                          _buildReplyPreview(),

                        // Message content bubble
                        _buildMessageBubble(context),
                      ],
                    ),
                  ),
                ),
                if (widget.isFromCurrentUser) ...[
                  const SizedBox(width: 8),
                  _buildAvatar(),
                ],
              ],
            ),

            // Message metadata (timestamp, read status, etc.)
            _buildMessageMetadata(),

            // Reactions
            if (widget.message.reactions.isNotEmpty) _buildReactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[800],
      ),
      child:
          widget.message.senderAvatar != null
              ? ClipOval(
                child: Image.network(
                  widget.message.senderAvatar!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildDefaultAvatar();
                  },
                ),
              )
              : _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[800],
      ),
      child: Center(
        child: Text(
          widget.message.senderName.isNotEmpty
              ? widget.message.senderName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: const Color(0xFF4ECDC4), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.replyTo!.senderName,
            style: const TextStyle(
              color: Color(0xFF4ECDC4),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.message.replyTo!.content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            widget.isFromCurrentUser
                ? const Color(0xFF4ECDC4)
                : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft:
              widget.isFromCurrentUser
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
          bottomRight:
              widget.isFromCurrentUser
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
        ),
      ),
      child: _buildContentByType(context),
    );
  }

  Widget _buildContentByType(BuildContext context) {
    switch (widget.message.type) {
      case MessageType.text:
        return _buildTextContent();
      case MessageType.image:
        return _buildImageContent(context);
      case MessageType.video:
        return _buildVideoContent(context);
      case MessageType.audio:
        return _buildAudioContent();
      case MessageType.file:
        return _buildFileContent();
      case MessageType.lottie:
        return _buildLottieContent();
      case MessageType.svga:
        return _buildSvgaContent();
      case MessageType.location:
        return _buildLocationContent();
      case MessageType.contact:
        return _buildContactContent();
      case MessageType.system:
        return _buildSystemContent();
    }
  }

  Widget _buildTextContent() {
    return SelectableText(
      widget.message.content ?? '',
      style: TextStyle(
        color: widget.isFromCurrentUser ? Colors.white : Colors.white,
        fontSize: 16,
        height: 1.3,
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.message.content != null &&
            widget.message.content!.isNotEmpty) ...[
          Text(
            widget.message.content!,
            style: TextStyle(
              color: widget.isFromCurrentUser ? Colors.white : Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            widget.message.media!.url,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
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
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.image, color: Colors.grey, size: 48),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.message.content != null &&
            widget.message.content!.isNotEmpty) ...[
          Text(
            widget.message.content!,
            style: TextStyle(
              color: widget.isFromCurrentUser ? Colors.white : Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  widget.message.media!.thumbnailUrl != null
                      ? Image.network(
                        widget.message.media!.thumbnailUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.videocam,
                                color: Colors.grey,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      )
                      : Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.videocam,
                            color: Colors.grey,
                            size: 48,
                          ),
                        ),
                      ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
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
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.message.media!.formattedDuration,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudioContent() {
    return GestureDetector(
      onTap: _toggleAudioPlayback,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4),
                shape: BoxShape.circle,
              ),
              child:
                  _isPlayingAudio
                      ? const Icon(Icons.pause, color: Colors.white, size: 24)
                      : const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.mic,
                        color: Colors.white.withOpacity(0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Audio Message',
                        style: TextStyle(
                          color:
                              widget.isFromCurrentUser
                                  ? Colors.white
                                  : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Audio waveform visualization (simplified)
                      Expanded(
                        child: SizedBox(
                          height: 20,
                          child: Row(
                            children: List.generate(20, (index) {
                              final height = (index % 4 + 1) * 3.0;
                              return Container(
                                width: 2,
                                height: height,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isPlayingAudio
                                          ? const Color(0xFF4ECDC4)
                                          : Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.message.media?.formattedDuration ?? '0:00',
                        style: TextStyle(
                          color: (widget.isFromCurrentUser
                                  ? Colors.white
                                  : Colors.white)
                              .withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle audio playback
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

          // Listen for playback completion
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
      print('Error toggling audio playback: $e');
    }
  }

  Widget _buildFileContent() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.attach_file, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.message.media!.fileName,
                style: TextStyle(
                  color: widget.isFromCurrentUser ? Colors.white : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.message.media!.formattedFileSize,
                style: TextStyle(
                  color: (widget.isFromCurrentUser
                          ? Colors.white
                          : Colors.white)
                      .withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLottieContent() {
    return Column(
      children: [
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.animation, color: Colors.white, size: 48),
          ),
        ),
        if (widget.message.content != null &&
            widget.message.content!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.message.content!,
              style: TextStyle(
                color: widget.isFromCurrentUser ? Colors.white : Colors.white,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSvgaContent() {
    return Column(
      children: [
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.animation, color: Colors.white, size: 48),
          ),
        ),
        if (widget.message.content != null &&
            widget.message.content!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.message.content!,
              style: TextStyle(
                color: widget.isFromCurrentUser ? Colors.white : Colors.white,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationContent() {
    return Row(
      children: [
        const Icon(Icons.location_on, color: Color(0xFF4ECDC4), size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.message.content ?? 'Location',
            style: TextStyle(
              color: widget.isFromCurrentUser ? Colors.white : Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactContent() {
    return Row(
      children: [
        const Icon(Icons.person, color: Color(0xFF4ECDC4), size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.message.content ?? 'Contact',
            style: TextStyle(
              color: widget.isFromCurrentUser ? Colors.white : Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemContent() {
    return Text(
      widget.message.content ?? '',
      style: TextStyle(
        color: Colors.grey[400],
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildMessageMetadata() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment:
            widget.isFromCurrentUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
        children: [
          Text(
            widget.message.formattedTime,
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
          if (widget.isFromCurrentUser) ...[
            const SizedBox(width: 4),
            Icon(
              widget.message.status == MessageStatus.read
                  ? Icons.done_all
                  : Icons.done,
              color:
                  widget.message.status == MessageStatus.read
                      ? const Color(0xFF4ECDC4)
                      : Colors.grey[500],
              size: 12,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReactions() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children:
            widget.message.groupedReactions.entries.map((entry) {
              return GestureDetector(
                onTap: () => widget.onReactionTap?.call(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        entry.value.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}
