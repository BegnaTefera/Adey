import 'package:flutter/material.dart';

/// Color palette — copied 1:1 from the Figma export's `src/index.css`
/// `@theme inline` block, so the Flutter app matches the approved design.
class AppColors {
  AppColors._();

  static const background = Color(0xFFF7F5F2);
  static const foreground = Color(0xFF1A1916);
  static const card = Color(0xFFFFFFFF);
  static const cardForeground = Color(0xFF1A1916);
  static const muted = Color(0xFFF0EDE8);
  static const mutedForeground = Color(0xFF7A7570);
  static const border = Color(0xFFE4E0DA);
  static const primary = Color(0xFF2D5A3D);
  static const primaryForeground = Color(0xFFFFFFFF);
  static const accent = Color(0xFFE8A838);
  static const accentForeground = Color(0xFF1A1916);
  static const danger = Color(0xFFC0392B);
  static const dangerSoft = Color(0xFFFDF2F1);
  static const sync = Color(0xFF3A9E6F);

  // Small soft-background tones used inline in the original design
  // (pending/print banner, on-file badges, etc.)
  static const pendingSoft = Color(0xFFFFFBF0);
  static const pendingBorder = Color(0xFFF0D070);
  static const pendingBadge = Color(0xFFFDE98A);
  static const syncSoft = Color(0xFFEDF7F1);
  static const pendingTextDark = Color(0xFFB07D00);
}

/// Text styles — `DM Sans` for body/UI text, `DM Mono` for the small
/// uppercase labels and numeric/mono figures used throughout the design.
class AppText {
  AppText._();

  static const List<String> _ethiopicFallback = ['NotoSansEthiopic'];

  static const TextStyle _sans = TextStyle(
    fontFamily: 'sans-serif',
    fontFamilyFallback: _ethiopicFallback,
  );
  static const TextStyle _mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: _ethiopicFallback,
  );

  static TextStyle monoLabel = _mono.copyWith(
    fontSize: 11,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedForeground,
  );

  static TextStyle pageTitle = _sans.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.foreground,
  );

  static TextStyle sectionTitle = _sans.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.foreground,
  );

  static TextStyle bodyMedium = _sans.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.foreground,
  );

  static TextStyle bodyRegular = _sans.copyWith(
    fontSize: 14,
    color: AppColors.foreground,
  );

  static TextStyle caption = _sans.copyWith(
    fontSize: 12,
    color: AppColors.mutedForeground,
  );

  static TextStyle monoCaption = _mono.copyWith(
    fontSize: 12,
    color: AppColors.mutedForeground,
  );

  static TextStyle bigNumber = _sans.copyWith(
    fontSize: 44,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.0,
    color: AppColors.foreground,
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'sans-serif',
    fontFamilyFallback: const ['NotoSansEthiopic'],
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.card,
      error: AppColors.danger,
    ),
    dividerColor: AppColors.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.card,
      foregroundColor: AppColors.foreground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

/// Shared card decoration — the rounded-2xl white card with a hairline
/// border used everywhere in the design (dashboard sections, list
/// containers, profile blocks, etc.)
BoxDecoration cardDecoration({Color? color}) {
  return BoxDecoration(
    color: color ?? AppColors.card,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: AppColors.foreground.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
