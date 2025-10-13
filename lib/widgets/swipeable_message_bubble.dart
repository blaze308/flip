import 'dart:async';
import 'package:flutter/material.dart';

/// WhatsApp-style swipeable message bubble
/// Swipe LEFT: Shows More and Reply/Archive buttons (like chat list)
class SwipeableMessageBubble extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;
  final VoidCallback? onMore;
  final VoidCallback? onArchive;
  final bool isFromCurrentUser;
  final double threshold;

  const SwipeableMessageBubble({
    super.key,
    required this.child,
    this.onReply,
    this.onMore,
    this.onArchive,
    this.isFromCurrentUser = false,
    this.threshold = 80,
  });

  @override
  State<SwipeableMessageBubble> createState() => _SwipeableMessageBubbleState();
}

class _SwipeableMessageBubbleState extends State<SwipeableMessageBubble>
    with SingleTickerProviderStateMixin {
  double _dragExtent = 0;
  late AnimationController _controller;
  Animation<double> _animation = const AlwaysStoppedAnimation(0);
  bool _isRevealed = false;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoCloseTimer() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isRevealed) {
        _animateToZero();
      }
    });
  }

  void _handleDragStart(DragStartDetails details) {
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.primaryDelta!;

      // CORRECT LOGIC:
      // Incoming messages (on LEFT) → swipe RIGHT (positive drag)
      // Sent messages (on RIGHT) → swipe LEFT (negative drag)
      if (!widget.isFromCurrentUser) {
        // Incoming message (on LEFT side) - swipe RIGHT to reveal actions
        if (_dragExtent < 0) {
          // Left swipe - elastic resistance
          _dragExtent = _dragExtent * 0.3;
          _dragExtent = _dragExtent.clamp(-30.0, 0.0);
        } else {
          // Right swipe - normal
          _dragExtent = _dragExtent.clamp(0.0, 160.0);
        }
      } else {
        // Sent message (on RIGHT side) - swipe LEFT to reveal actions
        if (_dragExtent > 0) {
          // Right swipe - elastic resistance
          _dragExtent = _dragExtent * 0.3;
          _dragExtent = _dragExtent.clamp(0.0, 30.0);
        } else {
          // Left swipe - normal
          _dragExtent = _dragExtent.clamp(-160.0, 0.0);
        }
      }
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    // CORRECT LOGIC:
    // Incoming messages (on LEFT) → swipe RIGHT reveals actions on LEFT
    // Sent messages (on RIGHT) → swipe LEFT reveals actions on RIGHT
    if (!widget.isFromCurrentUser) {
      // Incoming message - swipe RIGHT
      if (_dragExtent > widget.threshold) {
        _animateToPosition(160);
        setState(() {
          _isRevealed = true;
        });
        _startAutoCloseTimer();
      } else {
        _animateToZero();
        setState(() {
          _isRevealed = false;
        });
      }
    } else {
      // Sent message - swipe LEFT
      if (_dragExtent < -widget.threshold) {
        _animateToPosition(-160);
        setState(() {
          _isRevealed = true;
        });
        _startAutoCloseTimer();
      } else {
        _animateToZero();
        setState(() {
          _isRevealed = false;
        });
      }
    }
  }

  void _animateToZero() {
    _autoCloseTimer?.cancel();
    _animation = Tween<double>(
      begin: _dragExtent,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _animation.addListener(() {
      setState(() {
        _dragExtent = _animation.value;
      });
    });

    _controller.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _isRevealed = false;
        });
      }
    });
  }

  void _animateToPosition(double position) {
    _animation = Tween<double>(
      begin: _dragExtent,
      end: position,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _animation.addListener(() {
      setState(() {
        _dragExtent = _animation.value;
      });
    });

    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Show actions based on swipe direction and message type
    // CORRECT LOGIC:
    // Incoming (LEFT side): swipe RIGHT (+drag) shows actions on LEFT
    // Sent (RIGHT side): swipe LEFT (-drag) shows actions on RIGHT
    final showActions =
        !widget.isFromCurrentUser
            ? _dragExtent >
                40 // Incoming: right swipe (positive)
            : _dragExtent < -40; // Sent: left swipe (negative)

    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      onTap: () {
        // Dismiss on tap if revealed
        if (_isRevealed) {
          _animateToZero();
        }
      },
      child: Stack(
        children: [
          // Background actions (position based on message type)
          if (showActions)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment:
                      !widget.isFromCurrentUser
                          ? MainAxisAlignment
                              .start // Incoming: buttons on LEFT
                          : MainAxisAlignment.end, // Sent: buttons on RIGHT
                  children: [
                    // More button
                    GestureDetector(
                      onTap: () {
                        _animateToZero();
                        widget.onMore?.call();
                      },
                      child: Container(
                        width: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFF54656F),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'More',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Reply/Archive button (changes based on who sent)
                    GestureDetector(
                      onTap: () {
                        _animateToZero();
                        if (widget.isFromCurrentUser) {
                          widget.onArchive?.call();
                        } else {
                          widget.onReply?.call();
                        }
                      },
                      child: Container(
                        width: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFF128C7E),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.isFromCurrentUser
                                  ? Icons.archive_outlined
                                  : Icons.reply_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isFromCurrentUser ? 'Archive' : 'Reply',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Message bubble
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
