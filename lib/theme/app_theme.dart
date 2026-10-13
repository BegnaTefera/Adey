// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// Color palette copied 1:1 from the Figma export's `src/index.css`
/// `@theme inline` block, so the Flutter app matches the approved design.
class AppColors {
  AppColors._();

  static const background = Color(0xFFF7F5F2);
  static const foreground = Color(0xFF1A1916);
  static const card = Color(0xFFFFFFFF);
  static const cardForeground = Color(0xFF1A1916);
  static const muted = Color(0xFFF0EDE8);
  static const mutedForeground = Color(0xFF6E6963);
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
  static const pendingTextDark = Color(0xFF8A6100);
}

/// Text styles `DM Sans` for body/UI text, `DM Mono` for the small
/// uppercase labels and numeric/mono figures used throughout the design.
class AppText {
  AppText._();

  static const List<String> _ethiopicFallback = ['NotoSansEthiopic'];

  static const TextStyle _sans = TextStyle(
    fontFamily: 'DMSans',
    fontFamilyFallback: _ethiopicFallback,
  );
  static const TextStyle _mono = TextStyle(
    fontFamily: 'DMMono',
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
    fontFamily: 'DMSans',
    fontFamilyFallback: const ['NotoSansEthiopic'],
    textTheme: TextTheme(
      displayLarge: AppText.bigNumber,
      titleLarge: AppText.sectionTitle,
      titleMedium: AppText.bodyMedium,
      bodyLarge: AppText.bodyRegular,
      bodyMedium: AppText.bodyRegular,
      bodySmall: AppText.caption,
      labelLarge: AppText.bodyMedium,
      labelSmall: AppText.monoCaption,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.card,
      error: AppColors.danger,
    ),
    dividerColor: AppColors.border,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.card,
      foregroundColor: AppColors.foreground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppText.sectionTitle,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryForeground,
        textStyle:
            AppText.bodyMedium.copyWith(color: AppColors.primaryForeground),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryForeground,
        textStyle:
            AppText.bodyMedium.copyWith(color: AppColors.primaryForeground),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppText.bodyMedium.copyWith(color: AppColors.primary),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppText.bodyMedium.copyWith(color: AppColors.primary),
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.primaryForeground,
      elevation: 2,
      shape: StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: AppText.caption,
      labelStyle:
          AppText.bodyRegular.copyWith(color: AppColors.mutedForeground),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 80,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return AppText.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.primary : AppColors.mutedForeground,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.primary : AppColors.mutedForeground,
        );
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.card,
      modalBackgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      titleTextStyle: AppText.sectionTitle,
      contentTextStyle: AppText.bodyRegular,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// Shared card decoration the rounded-2xl white card with a hairline
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
