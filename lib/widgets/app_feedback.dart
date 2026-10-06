import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppFeedbackKind { success, error, info }

void showAppFeedback(
  BuildContext context, {
  required String message,
  AppFeedbackKind kind = AppFeedbackKind.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final (icon, color) = switch (kind) {
    AppFeedbackKind.success => (Icons.check_circle_outline, AppColors.sync),
    AppFeedbackKind.error => (Icons.error_outline, AppColors.danger),
    AppFeedbackKind.info => (Icons.info_outline, AppColors.primary),
  };

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.card,
        duration: const Duration(seconds: 4),
        content: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              ExcludeSemantics(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(kind),
                  tween: Tween(begin: 0.75, end: 1),
                  duration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: Icon(icon, color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyRegular.copyWith(
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppColors.primary,
                onPressed: onAction,
              )
            : null,
      ),
    );
}