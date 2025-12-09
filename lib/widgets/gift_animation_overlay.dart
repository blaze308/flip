import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/gift_model.dart';
import '../widgets/svga_player_widget.dart';

/// Gift Animation Overlay
/// Shows animated gifts when sent in live streams
class GiftAnimationOverlay extends StatefulWidget {
  final GiftModel gift;
  final String senderName;
  final VoidCallback onComplete;

  const GiftAnimationOverlay({
    super.key,
    required this.gift,
    required this.senderName,
    required this.onComplete,
  });

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          widget.onComplete();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Stack(
          children: [
            // Gift info banner
            Positioned(
              left: 16,
              bottom: 200,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4ECDC4).withOpacity(0.9),
                          const Color(0xFF667eea).withOpacity(0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4ECDC4).withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.card_giftcard,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.senderName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'sent ${widget.gift.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Gift animation (center)
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildGiftAnimation(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftAnimation() {
    // Check gift type and show appropriate animation
    if (widget.gift.type == GiftType.svga) {
      return SvgaPlayerWidget(
        svgaUrl: widget.gift.svgaUrl,
        width: 300,
        height: 300,
        loop: false,
      );
    } else if (widget.gift.type == GiftType.mp4) {
      // TODO: Implement MP4 player if needed
      return Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Icon(Icons.card_giftcard, color: Colors.white, size: 100),
        ),
      );
    } else if (widget.gift.type == GiftType.gif) {
      // GIF type - show cached network image
      return CachedNetworkImage(
        imageUrl: widget.gift.svgaUrl,
        width: 300,
        height: 300,
        fit: BoxFit.contain,
      );
    } else {
      // Fallback: show gift icon with scale animation
      return ScaleTransition(
        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
        ),
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4ECDC4).withOpacity(0.3),
                const Color(0xFF667eea).withOpacity(0.3),
              ],
            ),
          ),
          child: const Center(
            child: Icon(Icons.card_giftcard, color: Colors.white, size: 100),
          ),
        ),
      );
    }
  }
}
