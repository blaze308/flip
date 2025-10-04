import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'waveform_animation.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onAudioRecord;
  final VoidCallback? onAudioPause;
  final VoidCallback? onAudioStop;
  final bool isRecording;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSend,
    this.onAttachment,
    this.onAudioRecord,
    this.onAudioPause,
    this.onAudioStop,
    this.isRecording = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with TickerProviderStateMixin {
  late AnimationController _sendButtonController;
  late AnimationController _recordingController;
  late Animation<double> _sendButtonAnimation;
  late Animation<double> _recordingAnimation;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _sendButtonController.dispose();
    _recordingController.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _setupAnimations() {
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _sendButtonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sendButtonController, curve: Curves.easeInOut),
    );

    _recordingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _recordingAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _recordingController, curve: Curves.easeInOut),
    );
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });

      if (hasText) {
        _sendButtonController.forward();
      } else {
        _sendButtonController.reverse();
      }
    }

    widget.onChanged(widget.controller.text);
  }

  @override
  void didUpdateWidget(MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _recordingController.repeat(reverse: true);
      } else {
        _recordingController.stop();
        _recordingController.reset();
      }
    }
  }

  void _handleSend() {
    if (widget.controller.text.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: widget.isRecording ? _buildRecordingView() : _buildNormalView(),
      ),
    );
  }

  Widget _buildNormalView() {
    return Row(
      children: [
        // Attachment button
        if (widget.onAttachment != null)
          GestureDetector(
            onTap: widget.onAttachment,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add, color: Color(0xFF4ECDC4), size: 24),
            ),
          ),

        if (widget.onAttachment != null) const SizedBox(width: 12),

        // Text input
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: widget.controller,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Write now...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              maxLines: 5,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => _handleSend(),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Mic/Send button
        AnimatedBuilder(
          animation: _sendButtonAnimation,
          builder: (context, child) {
            return GestureDetector(
              onTap: _hasText ? _handleSend : null,
              onLongPressStart:
                  _hasText ? null : (_) => widget.onAudioRecord?.call(),
              onLongPressEnd:
                  _hasText ? null : (_) => widget.onAudioRecord?.call(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      _hasText
                          ? const Color(0xFF4ECDC4)
                          : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Transform.scale(
                  scale: 0.8 + (0.2 * _sendButtonAnimation.value),
                  child: Icon(
                    _hasText ? Icons.send : Icons.mic,
                    color: _hasText ? Colors.white : const Color(0xFF4ECDC4),
                    size: 20,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecordingView() {
    return Column(
      children: [
        // Simple text above
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Text(
            'Hold to record, release to send',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),

        // Recording container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF4ECDC4), width: 2),
          ),
          child: Row(
            children: [
              // Recording indicator (pulsing red dot)
              AnimatedBuilder(
                animation: _recordingAnimation,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(_recordingAnimation.value),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),

              const SizedBox(width: 16),

              // Waveform animation
              const Expanded(
                child: WaveformAnimation(
                  isRecording: true,
                  color: Color(0xFF4ECDC4),
                  height: 30,
                  barCount: 15,
                ),
              ),

              const SizedBox(width: 16),

              // Recording text
              const Text(
                'Recording...',
                style: TextStyle(
                  color: Color(0xFF4ECDC4),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(width: 12),

              // Pause button
              GestureDetector(
                onTap: widget.onAudioPause,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.pause, color: Colors.white, size: 18),
                ),
              ),

              const SizedBox(width: 8),

              // Stop button
              GestureDetector(
                onTap: widget.onAudioStop,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.stop, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
