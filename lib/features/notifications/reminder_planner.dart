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
    required this.loanId,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final String loanId;

  /// Horário local (dia + [ReminderPlanner.hour]).
  final DateTime at;
  final String title;
  final String body;
}

/// Regras de lembretes (puras e testáveis). O agendamento real fica em [ReminderService].
abstract final class ReminderPlanner {
  /// Hora local dos lembretes.
  static const int hour = 9;

  /// Limite seguro abaixo do teto de alarmes por app do Android (~500).
  static const int maxReminders = 400;

  /// Dias relativos ao vencimento em que avisamos: 7, 3, 1 dia antes, no dia e 1 dia depois.
  static const offsets = [-7, -3, -1, 0, 1];

  /// Janela de busca de operações (vencimentos até hoje + 8 dias cobrem o aviso de 7 dias;
  /// operações mais distantes são agendadas na próxima abertura do app).
  static const int lookaheadDays = 45;

  static List<PlannedReminder> plan(List<ReminderLoan> loans, {required DateTime now, bool hideAmounts = false}) {
    final candidates = <({DateTime at, ReminderLoan loan, int offset})>[];
    for (final loan in loans) {
      if (loan.remainingCents <= 0) continue;
      for (final offset in offsets) {
        final day = Dates.addDays(loan.dueDate, offset);
        final at = DateTime(day.year, day.month, day.day, hour);
        if (at.isAfter(now)) candidates.add((at: at, loan: loan, offset: offset));
      }
    }
    candidates.sort((a, b) => a.at.compareTo(b.at));

    final result = <PlannedReminder>[];
    for (final c in candidates.take(maxReminders)) {
      final texts = _texts(c.loan, c.offset, hideAmounts);
      result.add(
        PlannedReminder(id: result.length + 1, loanId: c.loan.loanId, at: c.at, title: texts.$1, body: texts.$2),
      );
    }
    return result;
  }

  static (String, String) _texts(ReminderLoan loan, int offset, bool hideAmounts) {
    final name = loan.clientName;
    final amount = Money.format(loan.remainingCents);
    final valuePart = hideAmounts ? '' : ' — $amount';
    return switch (offset) {
      -7 => (
        'Cobrança próxima do vencimento',
        hideAmounts ? '$name tem um valor a receber em 7 dias.' : '$name possui $amount a receber em 7 dias.',
      ),
      -3 => ('Vencimento se aproximando', 'A operação de $name vence em 3 dias.'),
      -1 => ('Operação vence amanhã', '$name$valuePart'),
      0 => ('Operação vence hoje', '$name$valuePart'),
      _ => ('Operação vencida', 'A operação de $name está vencida.'),
    };
  }
}
