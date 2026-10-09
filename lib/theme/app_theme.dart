import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const String font = 'Manrope';
  static const double radius = 24;
  static const double radiusSmall = 16;

  static ThemeData dark() => _build(Brightness.dark, NivvoColors.dark);
  static ThemeData light() => _build(Brightness.light, NivvoColors.light);

  static TextStyle _t(double size, FontWeight weight, Color color, {double spacing = 0, double? height}) => TextStyle(
    fontFamily: font,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: height,
  );

  static ThemeData _build(Brightness brightness, NivvoColors c) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: Colors.white,
      primaryContainer: c.brand.withValues(alpha: 0.18),
      onPrimaryContainer: isDark ? NivvoPalette.blueSoft : c.brand,
      secondary: NivvoPalette.blueBright,
      onSecondary: Colors.white,
      secondaryContainer: isDark ? const Color(0x24FFFFFF) : const Color(0x142B5BFF),
      onSecondaryContainer: isDark ? Colors.white : c.brand,
      tertiary: NivvoPalette.violet,
      onTertiary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.surfaceSolid,
      onSurface: c.text,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surfaceSolid,
      surfaceContainer: c.surfaceSolid,
      surfaceContainerHigh: c.surfaceSolid,
      surfaceContainerHighest: c.surfaceSolid,
      outline: c.border,
      outlineVariant: c.border,
    );

    final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme, fontFamily: font);

    final textTheme = base.textTheme
        .apply(bodyColor: c.text, displayColor: c.text, fontFamily: font)
        .copyWith(
          displaySmall: _t(40, FontWeight.w800, c.text, spacing: -1.6),
          headlineMedium: _t(30, FontWeight.w800, c.text, spacing: -1),
          headlineSmall: _t(25, FontWeight.w800, c.text, spacing: -0.7),
          titleLarge: _t(21, FontWeight.w800, c.text, spacing: -0.4),
          titleMedium: _t(16.5, FontWeight.w700, c.text, spacing: -0.2),
          titleSmall: _t(14.5, FontWeight.w700, c.text),
          bodyLarge: _t(16, FontWeight.w500, c.text),
          bodyMedium: _t(14.5, FontWeight.w500, c.text),
          bodySmall: _t(12.5, FontWeight.w500, c.textSecondary),
          labelLarge: _t(15, FontWeight.w700, c.text),
          labelMedium: _t(12.5, FontWeight.w600, c.textSecondary, spacing: 0.2),
          labelSmall: _t(11, FontWeight.w600, c.textSecondary, spacing: 0.3),
        );

    final pill = const StadiumBorder();
    final buttonText = _t(15.5, FontWeight.w700, Colors.white, spacing: -0.1);

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      canvasColor: c.surfaceSolid,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: _t(24, FontWeight.w800, c.text, spacing: -0.7),
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: c.brand.withValues(alpha: isDark ? 0.28 : 0.14),
        indicatorShape: pill,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? (isDark ? Colors.white : c.brand) : c.textSecondary,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => _t(
            11.5,
            s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            s.contains(WidgetState.selected) ? c.text : c.textSecondary,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.brand,
        foregroundColor: Colors.white,
        elevation: 6,
        highlightElevation: 8,
        shape: const StadiumBorder(),
        extendedTextStyle: _t(15, FontWeight.w800, Colors.white),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.surfaceHigh,
          disabledForegroundColor: c.textSecondary,
          minimumSize: const Size.fromHeight(56),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: pill,
          side: BorderSide(color: c.border),
          backgroundColor: c.surface,
          foregroundColor: c.text,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? NivvoPalette.blueSoft : c.brand,
          shape: pill,
          textStyle: _t(14.5, FontWeight.w700, c.brand),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: c.text)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.surface,
          selectedBackgroundColor: c.brand,
          selectedForegroundColor: Colors.white,
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          textStyle: _t(13.5, FontWeight.w700, c.text),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: _t(15, FontWeight.w500, c.textSecondary),
        labelStyle: _t(15, FontWeight.w500, c.textSecondary),
        floatingLabelStyle: _t(14, FontWeight.w600, isDark ? NivvoPalette.blueSoft : c.brand),
        suffixStyle: _t(16, FontWeight.w600, c.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusSmall), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: c.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: c.danger, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceHigh,
        selectedColor: c.brand,
        disabledColor: c.surfaceHigh,
        side: BorderSide(color: c.border),
        shape: pill,
        labelStyle: _t(13.5, FontWeight.w700, c.text),
        secondaryLabelStyle: _t(13.5, FontWeight.w700, Colors.white),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: _t(20, FontWeight.w800, c.text, spacing: -0.3),
        contentTextStyle: _t(15, FontWeight.w500, c.textSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        textStyle: _t(14.5, FontWeight.w600, c.text),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.brand,
        headerForegroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1A2140) : const Color(0xFF0E1324),
        contentTextStyle: _t(14, FontWeight.w600, Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        titleTextStyle: _t(15, FontWeight.w700, c.text),
        subtitleTextStyle: _t(13, FontWeight.w500, c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brand : c.surfaceHigh),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand, linearTrackColor: c.surfaceHigh),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
      ),
    );
  }
}
