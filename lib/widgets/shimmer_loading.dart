import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Modern shimmer loading widget
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  /// Circular shimmer (for avatars, buttons)
  const ShimmerLoading.circle({
    super.key,
    required double size,
  }) : width = size,
       height = size,
       shape = BoxShape.circle,
       borderRadius = null;

  /// Rectangular shimmer with custom border radius
  const ShimmerLoading.rect({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  }) : shape = BoxShape.rectangle;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3A3A3A),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          shape: shape,
          borderRadius: shape == BoxShape.rectangle ? (borderRadius ?? BorderRadius.circular(8)) : null,
        ),
      ),
    );
  }
}

/// Shimmer for story circles
class StoryShimmer extends StatelessWidget {
  const StoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF3A3A3A),
                width: 2,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: ShimmerLoading.circle(size: 62),
            ),
          ),
          const SizedBox(height: 8),
          const ShimmerLoading(
            width: 50,
            height: 10,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ],
      ),
    );
  }
}

/// Shimmer for post cards
class PostShimmer extends StatelessWidget {
  const PostShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const ShimmerLoading.circle(size: 40),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerLoading(width: 100, height: 12),
                  const SizedBox(height: 6),
                  ShimmerLoading(
                    width: 80,
                    height: 10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content
          const ShimmerLoading(width: double.infinity, height: 200),
          const SizedBox(height: 16),
          // Actions
          Row(
            children: [
              const ShimmerLoading(width: 60, height: 24),
              const SizedBox(width: 24),
              const ShimmerLoading(width: 60, height: 24),
              const SizedBox(width: 24),
              const ShimmerLoading(width: 60, height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

