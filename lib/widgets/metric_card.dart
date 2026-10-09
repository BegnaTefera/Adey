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
  final double width;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.valueColor,
    this.accent,
    this.width = 178,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.primary;
    return Container(
      width: width,
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

/// Wraps a set of [MetricCard]s so they reflow cleanly from one column on a
/// narrow phone to a full row on the desktop shell.
class MetricStrip extends StatelessWidget {
  final List<Widget> children;

  const MetricStrip({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }
}
