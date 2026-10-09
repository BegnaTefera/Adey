import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A compact KPI tile for the summary strip at the top of the Expenses and
/// Attendance screens. Label uses the mono label style; the value uses mono
/// figures so columns of numbers line up.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? valueColor;
  final Color? accent;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.valueColor,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: tint),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppText.monoCaption.copyWith(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.pageTitle.copyWith(
                fontSize: 22,
                color: valueColor ?? AppColors.foreground,
                fontFamily: AppText.monoCaption.fontFamily,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppText.caption.copyWith(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// Lays out a set of [MetricCard]s that adapt to the available width.
///
/// On the desktop shell the cards keep their compact 178px width in a single
/// row; on narrower windows they fall back to a 3-, 2- or 1-column grid whose
/// cells grow to share the full width, so a phone shows a tidy 2x2 block
/// instead of one tall stacked column.
class MetricStrip extends StatelessWidget {
  final List<Widget> children;

  const MetricStrip({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const maxCardWidth = 178.0;
        const minCardWidth = 128.0;
        final available = constraints.maxWidth;

        final count = children.isEmpty ? 1 : children.length;
        final fits = ((available + spacing) / (minCardWidth + spacing)).floor();
        var columns = fits < 1 ? 1 : fits;
        if (columns > count) columns = count;
        if (columns > 4) columns = 4;

        final rawWidth = (available - spacing * (columns - 1)) / columns;
        final cardWidth = rawWidth > maxCardWidth ? maxCardWidth : rawWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}
