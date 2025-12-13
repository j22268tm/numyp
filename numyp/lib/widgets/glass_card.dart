import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// ガラスモーフィズム効果を持つカードウィジェット
/// 地図の上に浮かぶUI要素として使用します
class GlassCard extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const GlassCard({
    super.key,
    this.width,
    this.height,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            width: width,
            height: height,
            padding: padding ?? const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.cardSurface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
