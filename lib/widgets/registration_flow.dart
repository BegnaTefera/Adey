// lib/widgets/registration_flow.dart
import 'package:flutter/material.dart';
import '../data/fee_types_store.dart';
import '../data/children_store.dart';
import '../widgets/app_feedback.dart';
import '../widgets/log_payment_sheet.dart';
import '../screens/register_screen.dart';

Future<void> startRegistration(BuildContext context, {required VoidCallback onOpenBilling}) async {
  if (!FeeTypesStore.instance.hasAnyFeeTypes) {
    showAppFeedback(
      context,
      kind: AppFeedbackKind.info,
      message: 'Add at least one fee type in Billing before registering a child.',
      actionLabel: 'Open Billing',
      onAction: onOpenBilling,
    );
    return;
  }

  final childId = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const RegisterScreen()),
  );
  if (!context.mounted || childId == null) return;

  final child = ChildrenStore.instance.byId(childId);
  if (child == null) return;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Child registered'),
      content: Text('${child.fullName} is enrolled. Record the registration fee now?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Record payment'),
        ),
      ],
    ),
  );

  if (result == true && context.mounted) {
    showLogPaymentSheet(context, initialChildId: childId);
  }
}
