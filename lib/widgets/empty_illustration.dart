import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A dependency-free empty-state illustration: a soft muted backdrop with a
/// couple of tinted accent blobs and the relevant icon on a floating disc.
/// Used instead of a bare icon so empty screens still communicate intent and
/// offer a next step.
class EmptyIllustration extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  const EmptyIllustration({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 148,
              height: 116,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(148, 116),
                    painter: _BlobPainter(
                      base: AppColors.muted,
                      accent: AppColors.primary.withValues(alpha: 0.12),
                      accentAlt: AppColors.accent.withValues(alpha: 0.18),
                    ),
                  ),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.foreground.withValues(alpha: 0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 30, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppText.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Color base;
  final Color accent;
  final Color accentAlt;

  const _BlobPainter({
    required this.base,
    required this.accent,
    required this.accentAlt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final backdrop = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.74,
        height: size.height * 0.74,
      ),
      Radius.circular(size.width * 0.28),
    );
    canvas.drawRRect(backdrop, Paint()..color = base);

    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.28),
      size.width * 0.09,
      Paint()..color = accent,
    );
    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.70),
      size.width * 0.13,
      Paint()..color = accentAlt,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.22),
      size.width * 0.05,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.accent != accent ||
      oldDelegate.accentAlt != accentAlt;
}
