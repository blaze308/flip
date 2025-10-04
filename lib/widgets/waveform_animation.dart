import 'package:flutter/material.dart';
import 'dart:math' as math;

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
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<AnimationController> _barControllers;
  late List<Animation<double>> _barAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Create individual controllers for each bar
    _barControllers = List.generate(
      widget.barCount,
      (index) => AnimationController(
        duration: Duration(
          milliseconds: 300 + (index * 50),
        ), // Staggered timing
        vsync: this,
      ),
    );

    // Create animations for each bar
    _barAnimations =
        _barControllers.map((controller) {
          return Tween<double>(begin: 0.1, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          );
        }).toList();
  }

  @override
  void didUpdateWidget(WaveformAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  void _startAnimation() {
    _animationController.repeat();

    // Start each bar with a slight delay
    for (int i = 0; i < _barControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted && widget.isRecording) {
          _barControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  void _stopAnimation() {
    _animationController.stop();
    for (final controller in _barControllers) {
      controller.stop();
      controller.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (final controller in _barControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.barCount, (index) {
          return AnimatedBuilder(
            animation: _barAnimations[index],
            builder: (context, child) {
              // Create varying heights for a more natural waveform
              final baseHeight =
                  widget.isRecording
                      ? (0.3 + (math.sin(index * 0.5) * 0.2)) * widget.height
                      : widget.height * 0.2;

              final animatedHeight =
                  widget.isRecording
                      ? baseHeight * _barAnimations[index].value
                      : baseHeight;

              return Container(
                width: 3,
                height: animatedHeight,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(
                    widget.isRecording ? 0.8 : 0.3,
                  ),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            },
          );
        }),
      ),
    );
  }
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
