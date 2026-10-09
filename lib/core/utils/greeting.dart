/// Saudação conforme o horário do aparelho.
abstract final class Greeting {
  /// 05:00–11:59 bom dia · 12:00–17:59 boa tarde · 18:00–04:59 boa noite.
  static String forTime(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'Bom dia';
    if (h >= 12 && h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  /// "Bom dia, Daniel!" (primeiro nome) ou "Bom dia!" quando não há nome.
  static String message(DateTime now, String fullName) {
    final first = fullName.trim().split(RegExp(r'\s+')).first;
    final greeting = forTime(now);
    return first.isEmpty ? '$greeting!' : '$greeting, $first!';
  }
}
