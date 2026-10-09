import 'package:material_ui/material_ui.dart';

/// Paleta Nivvo — azul elétrico sobre um fundo escuro com "aurora" desfocada.
/// Superfícies são translúcidas (vidro) para deixar o brilho do fundo aparecer.
abstract final class NivvoPalette {
  // Marca
  static const blue = Color(0xFF2B5BFF); // azul elétrico
  static const blueBright = Color(0xFF4F7DFF);
  static const blueSoft = Color(0xFF8AA6FF);
  static const violet = Color(0xFF7A5CFF);
  static const cyan = Color(0xFF22C8FF);
  static const mint = Color(0xFF2FE0A8);

  // Status
  static const success = Color(0xFF2FE0A8);
  static const warning = Color(0xFFFFB648);
  static const danger = Color(0xFFFF5A70);
  static const neutral = Color(0xFF7D86A0);

  // Escuro
  static const darkBackground = Color(0xFF05070F);
  static const darkSurfaceSolid = Color(0xFF0E1324);

  // Claro
  static const lightBackground = Color(0xFFF3F5FC);
  static const lightSurfaceSolid = Color(0xFFFFFFFF);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blueBright, blue, violet],
  );
}

/// Cores semânticas acessíveis via `context.colors`, já resolvidas para o tema atual.
@immutable
class NivvoColors extends ThemeExtension<NivvoColors> {
  const NivvoColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceSolid,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.brand,
    required this.success,
    required this.warning,
    required this.danger,
    required this.neutral,
    required this.aurora,
    required this.auroraStrength,
  });

  /// Fundo da tela (por trás da aurora).
  final Color background;

  /// Cartões de vidro (translúcidos).
  final Color surface;

  /// Campos, chips e elementos sobre cartões (translúcidos, um pouco mais claros).
  final Color surfaceHigh;

  /// Superfícies opacas: folhas inferiores, diálogos, menus.
  final Color surfaceSolid;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color brand;
  final Color success;
  final Color warning;
  final Color danger;
  final Color neutral;

  /// Cores das manchas desfocadas do fundo.
  final List<Color> aurora;
  final double auroraStrength;

  static const dark = NivvoColors(
    background: NivvoPalette.darkBackground,
    surface: Color(0x12FFFFFF),
    surfaceHigh: Color(0x17FFFFFF),
    surfaceSolid: NivvoPalette.darkSurfaceSolid,
    border: Color(0x17FFFFFF),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF98A2BF),
    brand: NivvoPalette.blue,
    success: NivvoPalette.success,
    warning: NivvoPalette.warning,
    danger: NivvoPalette.danger,
    neutral: NivvoPalette.neutral,
    aurora: [NivvoPalette.blue, NivvoPalette.violet, NivvoPalette.cyan],
    auroraStrength: 1,
  );

  static const light = NivvoColors(
    background: NivvoPalette.lightBackground,
    surface: Color(0xC7FFFFFF),
    surfaceHigh: Color(0x0F0B1640),
    surfaceSolid: NivvoPalette.lightSurfaceSolid,
    border: Color(0x140B1640),
    text: Color(0xFF0A0F24),
    textSecondary: Color(0xFF5D6685),
    brand: NivvoPalette.blue,
    success: Color(0xFF0FA97A),
    warning: Color(0xFFC77F05),
    danger: Color(0xFFE5354F),
    neutral: Color(0xFF7D86A0),
    aurora: [Color(0xFF6E8EFF), Color(0xFFB4A2FF), Color(0xFF7FDBFF)],
    auroraStrength: 0.55,
  );

  @override
  NivvoColors copyWith() => this;

  @override
  NivvoColors lerp(NivvoColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension NivvoThemeContext on BuildContext {
  NivvoColors get colors => Theme.of(this).extension<NivvoColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
