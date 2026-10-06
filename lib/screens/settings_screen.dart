import 'package:flutter/material.dart';
import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Settings', style: AppText.sectionTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: cardDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              title: Text('Ethiopian calendar', style: AppText.bodyMedium),
              subtitle: Text(
                'Show dates in the Ethiopian calendar app-wide. Off shows Gregorian.',
                style: AppText.caption,
              ),
              value: SettingsStore.instance.useEthiopianCalendar,
              activeThumbColor: AppColors.primary,
              onChanged: _saveCalendarPreference,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCalendarPreference(bool value) async {
    try {
      await SettingsStore.instance.setUseEthiopianCalendar(value);
      if (!mounted) return;
      setState(() {});
      showAppFeedback(
        context,
        message: 'Calendar preference saved.',
        kind: AppFeedbackKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not save this preference. Try again. $error',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: () {
          _saveCalendarPreference(value);
        },
      );
    }
  }
}
