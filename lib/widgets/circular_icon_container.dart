import 'package:flutter/material.dart';

/// Circular icon button container widget
/// Used throughout the live streaming UI for consistent button styling
class CircularIconContainer extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double? size;
  final Key? key;

  const CircularIconContainer({
    this.key,
    required this.icon,
    this.onTap,
    this.color,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size ?? 35,
        height: size ?? 35,
        decoration: BoxDecoration(
          color: color ?? const Color(0xFF4ECDC4),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: (size ?? 35) * 0.5),
      ),
    );
  }
}
