import 'package:flutter/material.dart';
import '../data/formatters.dart';
import '../theme/app_theme.dart';

/// A tappable, labelled date slot that opens a date picker. Shows
/// [emptyLabel] until a [value] is chosen.
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String emptyLabel;

  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.emptyLabel = 'Any',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? emptyLabel : formatDate(value!),
                style: AppText.bodyRegular,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
