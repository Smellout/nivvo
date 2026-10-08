import 'package:intl/intl.dart';

/// Datas financeiras são dias de calendário (sem hora, sem fuso).
/// Internamente usamos DateTime UTC à meia-noite para que somas de dias
/// nunca sejam afetadas por horário de verão.
abstract final class Dates {
  static DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  static DateTime today([DateTime? now]) => dateOnly(now ?? DateTime.now());

  static DateTime addDays(DateTime d, int days) => DateTime.utc(d.year, d.month, d.day + days);

  /// Dias de `from` até `to` (negativo se `to` estiver no passado).
  static int daysBetween(DateTime from, DateTime to) => dateOnly(to).difference(dateOnly(from)).inDays;

  /// "2026-11-07" -> DateTime.utc(2026, 11, 7)
  static DateTime parse(Object? value) {
    if (value is DateTime) return dateOnly(value);
    final text = value as String;
    final d = DateTime.parse(text.length >= 10 ? text.substring(0, 10) : text);
    return DateTime.utc(d.year, d.month, d.day);
  }

  static DateTime? tryParse(Object? value) => value == null ? null : parse(value);

  /// DateTime -> "2026-11-07" (formato `date` do Postgres)
  static String toJson(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static final DateFormat _short = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _dayMonth = DateFormat("dd 'de' MMM", 'pt_BR');
  static final DateFormat _dayMonthShort = DateFormat('dd/MM', 'pt_BR');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'pt_BR');
  static final DateFormat _time = DateFormat('HH:mm', 'pt_BR');

  /// 07/11/2026
  static String short(DateTime d) => _short.format(d);

  /// 07 de nov.
  static String dayMonth(DateTime d) => _dayMonth.format(d);

  /// 07/11
  static String dayMonthShort(DateTime d) => _dayMonthShort.format(d);

  /// outubro 2026
  static String monthYear(DateTime d) => _monthYear.format(d);

  static String time(DateTime d) => _time.format(d.toLocal());

  /// "Vence hoje", "Vence amanhã", "Vence em 5 dias", "Venceu ontem", "Venceu há 3 dias"
  static String relativeDue(DateTime due, DateTime today) {
    final days = daysBetween(today, due);
    if (days == 0) return 'Vence hoje';
    if (days == 1) return 'Vence amanhã';
    if (days > 1) return 'Vence em $days dias';
    if (days == -1) return 'Venceu ontem';
    return 'Venceu há ${-days} dias';
  }
}
