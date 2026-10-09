import 'dart:io';

import 'package:flutter/material.dart';

import '../models/child.dart';
import '../theme/app_theme.dart';

/// Circular child avatar: shows the child's captured photo when one is on
/// file locally, and falls back to their initials otherwise. Used across
/// the app; the child profile builds its own larger version.
class ChildAvatar extends StatelessWidget {
  final Child child;
  final double radius;
  final double? fontSize;

  const ChildAvatar({
    super.key,
    required this.child,
    this.radius = 20,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final photoPath = child.photoPath;
    final size = radius * 2;
    Widget initials() => Center(
          child: Text(
            child.initials,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize ?? radius * 0.7,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photoPath == null
            ? ColoredBox(color: AppColors.primary, child: initials())
            : Image.file(
                File(photoPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: AppColors.primary, child: initials()),
              ),
      ),
    );
  }
}
