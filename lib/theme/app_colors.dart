import 'package:material_ui/material_ui.dart';

/// Paleta Nivvo. Marca: azul elétrico ("Nivvo Blue") com acento menta.
/// Status usam cores próprias para não competir com a marca.
abstract final class NivvoPalette {
  // Marca
  static const blue = Color(0xFF4F7CFF);
  static const blueSoft = Color(0xFF7C9DFF);
  static const mint = Color(0xFF2FD6A0);

  // Status
  static const success = Color(0xFF2FD6A0);
  static const warning = Color(0xFFF5B83D);
  static const danger = Color(0xFFFF5D6C);
  static const neutral = Color(0xFF7A8296);
  static const info = Color(0xFF7C9DFF);

  // Escuro
  static const darkBackground = Color(0xFF0B0F19);
  static const darkSurface = Color(0xFF151A24);
  static const darkSurfaceHigh = Color(0xFF1D2330);
  static const darkBorder = Color(0xFF262D3B);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF8B93A7);

  // Claro
  static const lightBackground = Color(0xFFF5F6FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFEEF0F6);
  static const lightBorder = Color(0xFFE2E5EE);
  static const lightText = Color(0xFF0B0F19);
  static const lightTextSecondary = Color(0xFF5E667A);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, mint],
  );
}

/// Cores semânticas acessíveis via `context.colors`, já resolvidas para o tema atual.
@immutable
class NivvoColors extends ThemeExtension<NivvoColors> {
  const NivvoColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.brand,
    required this.success,
    required this.warning,
    required this.danger,
    required this.neutral,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color brand;
  final Color success;
  final Color warning;
  final Color danger;
  final Color neutral;

  static const dark = NivvoColors(
    background: NivvoPalette.darkBackground,
    surface: NivvoPalette.darkSurface,
    surfaceHigh: NivvoPalette.darkSurfaceHigh,
    border: NivvoPalette.darkBorder,
    text: NivvoPalette.darkText,
    textSecondary: NivvoPalette.darkTextSecondary,
    brand: NivvoPalette.blue,
    success: NivvoPalette.success,
    warning: NivvoPalette.warning,
    danger: NivvoPalette.danger,
    neutral: NivvoPalette.neutral,
  );

  static const light = NivvoColors(
    background: NivvoPalette.lightBackground,
    surface: NivvoPalette.lightSurface,
    surfaceHigh: NivvoPalette.lightSurfaceHigh,
    border: NivvoPalette.lightBorder,
    text: NivvoPalette.lightText,
    textSecondary: NivvoPalette.lightTextSecondary,
    brand: NivvoPalette.blue,
    success: Color(0xFF12A77A),
    warning: Color(0xFFC98A0C),
    danger: Color(0xFFE5394B),
    neutral: Color(0xFF7A8296),
  );

  @override
  NivvoColors copyWith() => this;

  @override
  NivvoColors lerp(NivvoColors? other, double t) {
    if (other == null) return this;
    return NivvoColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

extension NivvoThemeContext on BuildContext {
  NivvoColors get colors => Theme.of(this).extension<NivvoColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
