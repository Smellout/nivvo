import '../utils/dates.dart';

/// Ciclo de vida gravado no banco. Status temporais são derivados (ver [LoanStatusRules]).
enum LoanLifecycle {
  active,
  paid,
  cancelled;

  static LoanLifecycle fromJson(String value) => LoanLifecycle.values.byName(value);
}

/// Status exibido ao usuário.
enum LoanDisplayStatus {
  pending('Pendente', 'Pendente'),
  partial('Pagamento parcial', 'Parcial'),
  dueSoon('Próxima do vencimento', 'Vencendo'),
  dueToday('Vence hoje', 'Hoje'),
  overdue('Vencida', 'Vencida'),
  paid('Paga', 'Paga'),
  cancelled('Cancelada', 'Cancelada');

  const LoanDisplayStatus(this.label, this.shortLabel);
  final String label;

  /// Rótulo curto para listas, onde o espaço é disputado.
  final String shortLabel;

  bool get isOpen => this != paid && this != cancelled;
}

/// Resultado do cálculo de uma nova operação (prévia e confirmação usam o mesmo valor).
class LoanQuote {
  const LoanQuote({
    required this.principalCents,
    required this.rateHundredths,
    required this.termDays,
    required this.startDate,
    required this.interestCents,
    required this.dueDate,
  });

  final int principalCents;
  final int rateHundredths;
  final int termDays;
  final DateTime startDate;
  final int interestCents;
  final DateTime dueDate;

  int get totalCents => principalCents + interestCents;
}

/// Partes de um valor pago, na ordem de alocação encargos → juros → principal.
class PaymentAllocation {
  const PaymentAllocation({required this.chargesCents, required this.interestCents, required this.principalCents});

  final int chargesCents;
  final int interestCents;
  final int principalCents;

  /// Juros + encargos efetivamente recebidos.
  int get earningsCents => chargesCents + interestCents;
}

/// Regras financeiras puras. Espelham exatamente as funções SQL
/// (`create_loan`, `register_payment`…) — os testes garantem os exemplos da especificação.
abstract final class LoanCalculator {
  static const int maxTermDays = 3650;
  static const int maxRateHundredths = 99999; // 999,99%

  /// JUROS = PRINCIPAL × TAXA, arredondado ao centavo (meio para cima),
  /// igual ao `round(numeric, 2)` do Postgres para valores positivos.
  static int interest(int principalCents, int rateHundredths) {
    assert(principalCents >= 0 && rateHundredths >= 0);
    return (principalCents * rateHundredths + 5000) ~/ 10000;
  }

  static DateTime dueDate(DateTime startDate, int termDays) => Dates.addDays(startDate, termDays);

  static LoanQuote quote({
    required int principalCents,
    required int rateHundredths,
    required int termDays,
    required DateTime startDate,
  }) {
    return LoanQuote(
      principalCents: principalCents,
      rateHundredths: rateHundredths,
      termDays: termDays,
      startDate: Dates.dateOnly(startDate),
      interestCents: interest(principalCents, rateHundredths),
      dueDate: dueDate(startDate, termDays),
    );
  }

  /// SALDO = PRINCIPAL + JUROS + ENCARGOS − PAGAMENTOS
  static int balance({
    required int principalCents,
    required int interestCents,
    required int chargesCents,
    required int paidCents,
  }) {
    return principalCents + interestCents + chargesCents - paidCents;
  }

  static PaymentAllocation allocate({
    required int paidCents,
    required int principalCents,
    required int interestCents,
    required int chargesCents,
  }) {
    var left = paidCents;
    final charges = left < chargesCents ? left : chargesCents;
    left -= charges;
    final interest = left < interestCents ? left : interestCents;
    left -= interest;
    final principal = left < principalCents ? left : principalCents;
    return PaymentAllocation(chargesCents: charges, interestCents: interest, principalCents: principal);
  }
}

abstract final class LoanStatusRules {
  /// Janela de "Próxima do vencimento" (em dias).
  static const int dueSoonDays = 3;

  /// Precedência: Cancelada › Paga › Vencida › Vence hoje › Próxima › Parcial › Pendente.
  static LoanDisplayStatus resolve({
    required LoanLifecycle lifecycle,
    required int remainingCents,
    required int paidCents,
    required DateTime dueDate,
    required DateTime today,
  }) {
    if (lifecycle == LoanLifecycle.cancelled) return LoanDisplayStatus.cancelled;
    if (lifecycle == LoanLifecycle.paid || remainingCents <= 0) return LoanDisplayStatus.paid;

    final days = Dates.daysBetween(today, dueDate);
    if (days < 0) return LoanDisplayStatus.overdue;
    if (days == 0) return LoanDisplayStatus.dueToday;
    if (days <= dueSoonDays) return LoanDisplayStatus.dueSoon;
    if (paidCents > 0) return LoanDisplayStatus.partial;
    return LoanDisplayStatus.pending;
  }
}
