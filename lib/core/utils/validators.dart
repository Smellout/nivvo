abstract final class Validators {
  static String digitsOnly(String? v) => (v ?? '').replaceAll(RegExp(r'\D'), '');

  static String? name(String? v) {
    final t = (v ?? '').trim();
    if (t.length < 2) return 'Informe o nome (mín. 2 letras)';
    if (t.length > 120) return 'Nome muito longo';
    return null;
  }

  /// Telefone opcional: 10–11 dígitos (DDD + número) ou com DDI (12–13).
  static String? phone(String? v) {
    final d = digitsOnly(v);
    if (d.isEmpty) return null;
    if (d.length < 10 || d.length > 13) return 'Telefone inválido';
    return null;
  }

  /// CPF opcional, validado pelos dígitos verificadores.
  static String? cpf(String? v) {
    final d = digitsOnly(v);
    if (d.isEmpty) return null;
    return isValidCpf(d) ? null : 'CPF inválido';
  }

  static bool isValidCpf(String digits) {
    if (!RegExp(r'^\d{11}$').hasMatch(digits)) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;
    final n = digits.split('').map(int.parse).toList();
    for (var check = 9; check < 11; check++) {
      var sum = 0;
      for (var i = 0; i < check; i++) {
        sum += n[i] * (check + 1 - i);
      }
      final dv = (sum * 10) % 11 % 10;
      if (dv != n[check]) return false;
    }
    return true;
  }

  static String? email(String? v) {
    final t = (v ?? '').trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'E-mail inválido';
    return null;
  }

  static String? password(String? v) {
    if ((v ?? '').length < 8) return 'Mínimo de 8 caracteres';
    return null;
  }

  static String? reason(String? v) {
    if ((v ?? '').trim().length < 3) return 'Descreva o motivo';
    return null;
  }
}

abstract final class Formatters {
  /// 11987654321 -> (11) 98765-4321
  static String phone(String? digits) {
    final d = Validators.digitsOnly(digits);
    if (d.length == 11) return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
    if (d.length == 10) return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
    return d;
  }

  /// 12345678909 -> 123.456.789-09
  static String cpf(String? digits) {
    final d = Validators.digitsOnly(digits);
    if (d.length != 11) return d;
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
  }
}
