import '../../core/finance/loan_calculator.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';

/// Dados mínimos de uma operação para gerar lembretes.
class ReminderLoan {
  const ReminderLoan({
    required this.loanId,
    required this.clientName,
    required this.remainingCents,
    required this.dueDate,
  });

  final String loanId;
  final String clientName;
  final int remainingCents;
  final DateTime dueDate;
}

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.route,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;

  /// Tela aberta ao tocar na notificação (ex.: `/loans?filter=dueSoon`).
  final String route;

  /// Horário local (dia + [ReminderPlanner.hour]).
  final DateTime at;
  final String title;
  final String body;
}

/// Regras de lembretes (puras e testáveis). O agendamento real fica em [ReminderService].
///
/// No máximo dois avisos por dia, às 9h:
/// - **Chegando no prazo**: operações que vencem de hoje até [LoanStatusRules.dueSoonDays] dias
///   (as mesmas do filtro "Vencendo"). Ao tocar, abre Operações › Vencendo.
/// - **Venceu ontem**: operações que passaram do vencimento no dia anterior. Abre Operações › Vencidas.
abstract final class ReminderPlanner {
  /// Hora local dos lembretes.
  static const int hour = 9;

  /// Quantos dias à frente agendamos (o app reagenda a cada abertura e a cada alteração).
  static const int horizonDays = 42;

  /// Janela de busca de operações: cobre o último dia agendado + a janela "Vencendo".
  static const int lookaheadDays = horizonDays + LoanStatusRules.dueSoonDays;

  static const dueSoonRoute = '/loans?filter=dueSoon';
  static const overdueRoute = '/loans?filter=overdue';
  static const dueSoonTitle = 'Você tem operações chegando no prazo!';

  static List<PlannedReminder> plan(List<ReminderLoan> loans, {required DateTime now, bool hideAmounts = false}) {
    final open = loans.where((l) => l.remainingCents > 0).toList();
    final today = Dates.today(now);
    final result = <PlannedReminder>[];

    for (var i = 0; i <= horizonDays; i++) {
      final day = Dates.addDays(today, i);
      final at = DateTime(day.year, day.month, day.day, hour);
      if (!at.isAfter(now)) continue;

      final soon = open.where((l) {
        final days = Dates.daysBetween(day, l.dueDate);
        return days >= 0 && days <= LoanStatusRules.dueSoonDays;
      }).toList();
      if (soon.isNotEmpty) {
        result.add(
          PlannedReminder(
            id: result.length + 1,
            route: dueSoonRoute,
            at: at,
            title: dueSoonTitle,
            body: _dueSoonBody(soon, day, hideAmounts),
          ),
        );
      }

      final lapsed = open.where((l) => Dates.daysBetween(day, l.dueDate) == -1).toList();
      if (lapsed.isNotEmpty) {
        result.add(
          PlannedReminder(
            id: result.length + 1,
            route: overdueRoute,
            at: at,
            title: lapsed.length == 1 ? 'Operação vencida' : 'Operações vencidas',
            body: lapsed.length == 1
                ? 'A operação de ${lapsed.single.clientName} venceu ontem${_amount(lapsed, hideAmounts)}.'
                : '${lapsed.length} operações venceram ontem${_amount(lapsed, hideAmounts)}.',
          ),
        );
      }
    }
    return result;
  }

  static String _dueSoonBody(List<ReminderLoan> loans, DateTime day, bool hideAmounts) {
    if (loans.length > 1) {
      return '${loans.length} operações vencem em até ${LoanStatusRules.dueSoonDays} dias'
          '${_amount(loans, hideAmounts)}. Toque para ver.';
    }
    final loan = loans.single;
    final when = switch (Dates.daysBetween(day, loan.dueDate)) {
      0 => 'vence hoje',
      1 => 'vence amanhã',
      final d => 'vence em $d dias',
    };
    return 'A operação de ${loan.clientName} $when${_amount(loans, hideAmounts)}.';
  }

  static String _amount(List<ReminderLoan> loans, bool hide) =>
      hide ? '' : ' — ${Money.format(loans.fold(0, (s, l) => s + l.remainingCents))} a receber';
}
