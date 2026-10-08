import 'package:intl/intl.dart';

/// Valores monetários trafegam no app como **centavos inteiros** (`int`).
/// `double` só aparece na fronteira com o JSON da API.
abstract final class Money {
  static final NumberFormat _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 2);
  static final NumberFormat _compact = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 1);
  static final NumberFormat _plain = NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: 2);

  /// Converte `numeric` vindo do PostgREST (número ou string) em centavos.
  static int fromJson(Object? value) {
    if (value == null) return 0;
    if (value is int) return value * 100;
    if (value is num) return (value * 100).round();
    if (value is String) return parse(value.replaceAll(',', '.')) ?? 0;
    throw FormatException('Valor monetário inválido: $value');
  }

  /// Centavos -> número decimal aceito pelo `numeric` do Postgres.
  static num toJson(int cents) => cents % 100 == 0 ? cents ~/ 100 : cents / 100;

  /// Converte "300.10" / "300,1" / "300" em centavos sem passar por double.
  static int? parse(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    final match = RegExp(r'^(-)?(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
    if (match == null) return null;
    final sign = match.group(1) == null ? 1 : -1;
    final units = int.parse(match.group(2)!);
    final decimals = (match.group(3) ?? '').padRight(2, '0');
    return sign * (units * 100 + int.parse(decimals));
  }

  /// "R$ 1.234,56"
  static String format(int cents) => _currency.format(cents / 100).replaceAll(' ', ' ');

  /// "1.234,56" (sem símbolo)
  static String formatPlain(int cents) => _plain.format(cents / 100);

  /// "+ R$ 45,00" / "− R$ 100,00"
  static String formatSigned(int cents) => '${cents < 0 ? '−' : '+'} ${format(cents.abs())}';

  /// "R$ 12,4 mil" — para eixos de gráfico e espaços curtos.
  static String formatCompact(int cents) => _compact.format(cents / 100).replaceAll(' ', ' ');
}

/// Taxa de juros em **centésimos de ponto percentual** (1500 = 15%, 1250 = 12,5%).
abstract final class Rate {
  static int fromJson(Object? value) {
    if (value == null) return 0;
    if (value is num) return (value * 100).round();
    if (value is String) return parse(value) ?? 0;
    throw FormatException('Taxa inválida: $value');
  }

  static num toJson(int hundredths) => hundredths % 100 == 0 ? hundredths ~/ 100 : hundredths / 100;

  /// "15" / "12,5" / "12.75" -> centésimos. Máximo 2 casas.
  static int? parse(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d{1,3})(?:\.(\d{0,2}))?$').firstMatch(normalized);
    if (match == null) return null;
    final units = int.parse(match.group(1)!);
    final decimals = (match.group(2) ?? '').padRight(2, '0');
    return units * 100 + int.parse(decimals);
  }

  /// 1500 -> "15%", 1250 -> "12,5%", 1275 -> "12,75%"
  static String format(int hundredths) {
    final units = hundredths ~/ 100;
    final decimals = hundredths % 100;
    if (decimals == 0) return '$units%';
    final d = decimals % 10 == 0 ? '${decimals ~/ 10}' : decimals.toString().padLeft(2, '0');
    return '$units,$d%';
  }

  /// Texto editável (sem %): 1250 -> "12,5"
  static String formatInput(int hundredths) => format(hundredths).replaceAll('%', '');
}
