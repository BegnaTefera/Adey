import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Selectable filter chip shared by the Expenses and Attendance filter bars.
///
/// Selection is shown by the fill *and* a checkmark, so the state never relies
/// on color alone (WCAG 1.4.1). All filter chips in the app share this so the
/// selected style stays consistent across pages.
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final int? count;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(count == null ? label : '$label ($count)'),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      selectedColor: AppColors.primary,
      labelStyle: AppText.bodyMedium.copyWith(
        color: selected ? Colors.white : AppColors.foreground,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
