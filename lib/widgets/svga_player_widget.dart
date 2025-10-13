import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

/// Widget to play SVGA animations with caching using svgaplayer_flutter
class SvgaPlayerWidget extends StatefulWidget {
  final String svgaUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool autoPlay;
  final bool loop;
  final Widget Function(BuildContext context)? placeholder;
  final Widget Function(BuildContext context, dynamic error)? errorWidget;

  const SvgaPlayerWidget({
    super.key,
    required this.svgaUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.autoPlay = true,
    this.loop = true,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<SvgaPlayerWidget> createState() => _SvgaPlayerWidgetState();
}

class _SvgaPlayerWidgetState extends State<SvgaPlayerWidget>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAndCacheSvga();
  }

  Future<void> _loadAndCacheSvga() async {
    try {
      print('🎁 SvgaPlayerWidget: Loading SVGA from ${widget.svgaUrl}');

      // Initialize controller
      _controller = SVGAAnimationController(vsync: this);

      // Load SVGA from URL directly
      final videoItem = await SVGAParser.shared.decodeFromURL(widget.svgaUrl);

      if (!mounted) return;

      setState(() {
        _controller!.videoItem = videoItem;
        _isLoading = false;
      });

      // Auto play if enabled
      if (widget.autoPlay) {
        if (widget.loop) {
          _controller!.repeat();
        } else {
          _controller!.forward();
        }
      }

      print('✅ SvgaPlayerWidget: SVGA loaded and playing');
    } catch (e) {
      print('❌ SvgaPlayerWidget: Error loading SVGA: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder?.call(context) ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
              ),
            ),
          );
    }

    if (_hasError || _controller == null) {
      return widget.errorWidget?.call(context, 'Failed to load SVGA') ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: Icon(
                Icons.card_giftcard,
                size: 64,
                color: Color(0xFF4ECDC4),
              ),
            ),
          );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: SVGAImage(_controller!, fit: widget.fit),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

/// Fullscreen SVGA viewer with caching
class SvgaViewerScreen extends StatelessWidget {
  final String svgaUrl;
  final String? giftName;
  final int? giftWeight;

  const SvgaViewerScreen({
    super.key,
    required this.svgaUrl,
    this.giftName,
    this.giftWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // SVGA Player - fullscreen
            Center(
              child: SvgaPlayerWidget(
                svgaUrl: svgaUrl,
                fit: BoxFit.contain,
                autoPlay: true,
                loop: true,
              ),
            ),

            // Top bar with close button
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (giftName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.card_giftcard,
                            color: Color(0xFFFFD700),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            giftName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (giftWeight != null) ...[
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.monetization_on,
                              color: Color(0xFFFFD700),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$giftWeight',
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
