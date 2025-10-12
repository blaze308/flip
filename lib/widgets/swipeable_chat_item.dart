import 'dart:async';
import 'package:flutter/material.dart';

/// WhatsApp-style swipeable chat list item
/// Swipe left: Shows More options and Archive
class SwipeableChatItem extends StatefulWidget {
  final Widget child;
  final VoidCallback? onArchive;
  final VoidCallback? onMore;
  final double threshold;

  const SwipeableChatItem({
    super.key,
    required this.child,
    this.onArchive,
    this.onMore,
    this.threshold = 80,
  });

  @override
  State<SwipeableChatItem> createState() => _SwipeableChatItemState();
}

class _SwipeableChatItemState extends State<SwipeableChatItem>
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
      // Allow both directions but with elastic effect
      if (_dragExtent > 0) {
        // Right swipe - elastic resistance
        _dragExtent = _dragExtent * 0.3;
        _dragExtent = _dragExtent.clamp(0.0, 30.0);
      } else {
        // Left swipe - normal
        _dragExtent = _dragExtent.clamp(-160.0, 0.0);
      }
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    // If swiped left enough, snap to show actions
    if (_dragExtent < -widget.threshold) {
      _animateToPosition(-160);
      setState(() {
        _isRevealed = true;
      });
      _startAutoCloseTimer(); // Auto-close after 2 seconds
    }
    // Always return to zero (elastic bounce back)
    else {
      _animateToZero();
      setState(() {
        _isRevealed = false;
      });
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
    // Only show actions when swiped left significantly
    final showActions = _dragExtent < -40;

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
          // Background actions (only visible when swiped left enough)
          if (showActions)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
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
                    // Archive button
                    GestureDetector(
                      onTap: () {
                        _animateToZero();
                        widget.onArchive?.call();
                      },
                      child: Container(
                        width: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFF128C7E),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.archive_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Archive',
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
                  ],
                ),
              ),
            ),

          // Chat item
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
