import 'package:flutter/material.dart';

import '../data/date_range.dart';
import '../theme/app_theme.dart';
import 'app_filter_chip.dart';
import 'date_field.dart';

/// Preset date-range chips plus the two custom date fields, shared by the
/// Expenses and Attendance screens. The chips wrap so labels are never
/// clipped as more presets are added.
class RangeFilter extends StatelessWidget {
  final DateRangePreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ValueChanged<DateRangePreset> onChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const RangeFilter({
    super.key,
    required this.preset,
    required this.customStart,
    required this.customEnd,
    required this.onChanged,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATE RANGE', style: AppText.monoLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in DateRangePreset.values)
              AppFilterChip(
                label: option.label,
                selected: preset == option,
                onSelected: () => onChanged(option),
              ),
          ],
        ),
        if (preset == DateRangePreset.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DateField(
                  label: 'From',
                  value: customStart,
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(
                  label: 'To',
                  value: customEnd,
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
