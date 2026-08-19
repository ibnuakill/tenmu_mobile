import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted circle icon button (back/bookmark on hero image).
class GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final double size;

  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Color(0x44000000),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor ?? Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Dot indicator for image carousel — visual only.
class ImageDotIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final bool compact;

  const ImageDotIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            final active = i == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? (compact ? 18 : 16) : (compact ? 5 : 6),
              height: compact ? 5 : 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: active ? Colors.white : Colors.white54,
              ),
            );
          }),
        ),
      ),
    );
  }
}
