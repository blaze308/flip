import 'package:flutter/material.dart';
import 'dart:math';

class WaveformAnimation extends StatefulWidget {
  final bool isRecording;
  final Color color;
  final double width;
  final double height;
  final int barCount;

  const WaveformAnimation({
    super.key,
    required this.isRecording,
    this.color = const Color(0xFF4ECDC4),
    this.width = 200,
    this.height = 40,
    this.barCount = 20,
  });

  @override
  State<WaveformAnimation> createState() => _WaveformAnimationState();
}

class _WaveformAnimationState extends State<WaveformAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _barHeights = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Initialize bar heights
    for (int i = 0; i < widget.barCount; i++) {
      _barHeights.add(_random.nextDouble());
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(() {
      if (widget.isRecording) {
        setState(() {
          // Update random bars to create wave effect
          for (int i = 0; i < widget.barCount; i++) {
            if (_random.nextDouble() > 0.7) {
              _barHeights[i] = 0.2 + (_random.nextDouble() * 0.8);
            }
          }
        });
      }
    });

    if (widget.isRecording) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(WaveformAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _controller.repeat();
      } else {
        _controller.stop();
        // Reset to low heights when not recording
        setState(() {
          for (int i = 0; i < widget.barCount; i++) {
            _barHeights[i] = 0.2;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: WaveformPainter(
        barHeights: _barHeights,
        color: widget.color.withOpacity(widget.isRecording ? 0.9 : 0.3),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> barHeights;
  final Color color;

  WaveformPainter({required this.barHeights, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / barHeights.length;
    final paint =
        Paint()
          ..color = color
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.fill;

    for (int i = 0; i < barHeights.length; i++) {
      final barHeight = barHeights[i] * size.height;
      final x = i * barWidth;
      final y = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth * 0.7, barHeight),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) => true;
}

/// Circular waveform animation (alternative style)
class CircularWaveformAnimation extends StatefulWidget {
  final bool isRecording;
  final Color color;
  final double size;

  const CircularWaveformAnimation({
    super.key,
    required this.isRecording,
    this.color = const Color(0xFF4ECDC4),
    this.size = 100,
  });

  @override
  State<CircularWaveformAnimation> createState() =>
      _CircularWaveformAnimationState();
}

class _CircularWaveformAnimationState extends State<CircularWaveformAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(CircularWaveformAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
        _rippleController.repeat();
      } else {
        _pulseController.stop();
        _rippleController.stop();
        _pulseController.reset();
        _rippleController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple effect
          AnimatedBuilder(
            animation: _rippleAnimation,
            builder: (context, child) {
              return Container(
                width: widget.size * _rippleAnimation.value,
                height: widget.size * _rippleAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withOpacity(
                      widget.isRecording
                          ? (1.0 - _rippleAnimation.value) * 0.5
                          : 0.0,
                    ),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          // Pulsing center
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isRecording ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: widget.size * 0.4,
                  height: widget.size * 0.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(
                      widget.isRecording ? 0.8 : 0.3,
                    ),
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 24),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
