import '../../core/finance/loan_calculator.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../../shared/models/charge.dart';
import '../../shared/models/history_entry.dart';
import '../../shared/models/loan.dart';
import '../../shared/models/payment.dart';

enum StatementKind { principal, interest, charge, payment }

class StatementLine {
  const StatementLine({
    required this.kind,
    required this.title,
    required this.cents,
    this.date,
    this.subtitle,
    this.charge,
    this.payment,
  });

  final StatementKind kind;
  final String title;
  final String? subtitle;

  /// Positivo aumenta o saldo; negativo (pagamentos) diminui.
  final int cents;
  final DateTime? date;
  final LoanCharge? charge;
  final Payment? payment;
}

class Statement {
  const Statement(this.lines, this.balanceCents);

  final List<StatementLine> lines;
  final int balanceCents;
}

enum TimelineTone { neutral, positive, negative, warning, danger }

class TimelineEvent {
  const TimelineEvent({
    required this.date,
    required this.title,
    this.amountText,
    this.detail,
    this.tone = TimelineTone.neutral,
    this.struck = false,
    required this.order,
  });

  final DateTime date;
  final String title;
  final String? amountText;
  final String? detail;
  final TimelineTone tone;
  final bool struck;

  /// Desempate estável entre eventos do mesmo dia.
  final DateTime order;
}

abstract final class LoanStatementBuilder {
  /// Extrato: principal, juros, encargos ativos, pagamentos ativos → saldo.
  static Statement statement(LoanDetail d) {
    final loan = d.loan;
    final lines = <StatementLine>[
      StatementLine(
        kind: StatementKind.principal,
        title: 'Valor emprestado',
        cents: loan.principalCents,
        date: loan.startDate,
      ),
      StatementLine(
        kind: StatementKind.interest,
        title: 'Juros da operação',
        subtitle: Rate.format(loan.rateHundredths),
        cents: loan.interestCents,
        date: loan.startDate,
      ),
    ];

    final dated = <StatementLine>[
      for (final c in d.activeCharges)
        StatementLine(
          kind: StatementKind.charge,
          title: c.type.label,
          subtitle: c.description,
          cents: c.amountCents,
          date: c.chargeDate,
          charge: c,
        ),
      for (final p in d.activePayments)
        StatementLine(
          kind: StatementKind.payment,
          title: 'Pagamento',
          subtitle: p.method.label,
          cents: -p.amountCents,
          date: p.paymentDate,
          payment: p,
        ),
    ]..sort((a, b) => a.date!.compareTo(b.date!));
    lines.addAll(dated);

    final balance = LoanCalculator.balance(
      principalCents: loan.principalCents,
      interestCents: loan.interestCents,
      chargesCents: d.activeCharges.fold(0, (s, c) => s + c.amountCents),
      paidCents: d.activePayments.fold(0, (s, p) => s + p.amountCents),
    );
    return Statement(lines, balance);
  }

  /// Linha do tempo: eventos gravados + vencimento derivado da data.
  static List<TimelineEvent> timeline(LoanDetail d, DateTime today) {
    final loan = d.loan;
    final events = <TimelineEvent>[];

    for (final h in d.history) {
      final amount = h.amountCents;
      switch (h.action) {
        case HistoryAction.loanCreated:
          events.add(
            TimelineEvent(
              date: h.eventDate,
              title: 'Operação criada',
              amountText: Money.format(amount ?? loan.principalCents),
              order: h.createdAt,
            ),
          );
          events.add(
            TimelineEvent(
              date: h.eventDate,
              title: 'Juros da operação · ${Rate.format(Rate.fromJson(h.metadata['interest_rate'] ?? 0))}',
              amountText: Money.formatSigned(Money.fromJson(h.metadata['interest_amount'] ?? 0)),
              order: h.createdAt.add(const Duration(microseconds: 1)),
            ),
          );
        case HistoryAction.chargeAdded:
          final type = ChargeType.fromJson((h.metadata['type'] as String?) ?? 'other');
          events.add(
            TimelineEvent(
              date: h.eventDate,
              title: '${type.label} lançado',
              amountText: Money.formatSigned(amount ?? 0),
              detail: h.description,
              tone: TimelineTone.warning,
              order: h.createdAt,
            ),
          );
        case HistoryAction.chargeCancelled:
          events.add(
            TimelineEvent(
              date: h.eventDate,
              title: 'Encargo cancelado',
              amountText: Money.format(amount ?? 0),
              detail: h.description == null ? null : 'Motivo: ${h.description}',
              struck: true,
              order: h.createdAt,
            ),
          );
        case HistoryAction.paymentRegistered:
          final settled = h.metadata['settled'] == true;
          final method = PaymentMethod.fromJson((h.metadata['method'] as String?) ?? 'other');
          events.add(
            TimelineEvent(
              date: h.eventDate,
              title: settled ? 'Pagamento final' : 'Pagamento parcial',
              amountText: Money.formatSigned(-(amount ?? 0)),
              detail: [method.label, if (h.description != null) h.description].join(' · '),
              tone: TimelineTone.positive,
              order: h.createdAt,
            ),
          );
        case HistoryAction.paymentCancelled:
          events.add(
            TimelineEvent(
              date: h.eventDate,
              title: 'Pagamento estornado',
              amountText: Money.format(amount ?? 0),
              detail: h.description == null ? null : 'Motivo: ${h.description}',
              struck: true,
              tone: TimelineTone.danger,
              order: h.createdAt,
            ),
          );
        case HistoryAction.loanPaid:
          events.add(
            TimelineEvent(
              date: h.eventDate,
              title: 'Operação encerrada',
              detail: 'Saldo quitado',
              tone: TimelineTone.positive,
              order: h.createdAt,
            ),
          );
        case HistoryAction.loanReopened:
          events.add(
            TimelineEvent(
              date: h.eventDate,
              title: 'Operação reaberta',
              tone: TimelineTone.warning,
              order: h.createdAt,
            ),
          );
        case HistoryAction.loanCancelled:
          events.add(
            TimelineEvent(
              date: h.eventDate,
              title: 'Operação cancelada',
              detail: h.description == null ? null : 'Motivo: ${h.description}',
              tone: TimelineTone.danger,
              order: h.createdAt,
            ),
          );
      }
    }

    if (loan.lifecycle != LoanLifecycle.cancelled) {
      final dueOrder = DateTime.utc(loan.dueDate.year, loan.dueDate.month, loan.dueDate.day);
      events.add(
        TimelineEvent(
          date: loan.dueDate,
          title: Dates.daysBetween(today, loan.dueDate) >= 0 ? 'Vencimento previsto' : 'Vencimento',
          order: dueOrder,
        ),
      );
      if (loan.isActive && Dates.daysBetween(today, loan.dueDate) < 0) {
        final overdueDay = Dates.addDays(loan.dueDate, 1);
        events.add(
          TimelineEvent(
            date: overdueDay,
            title: 'Operação vencida',
            tone: TimelineTone.danger,
            order: DateTime.utc(overdueDay.year, overdueDay.month, overdueDay.day),
          ),
        );
      }
    }

    events.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.order.compareTo(b.order);
    });
    return events;
  }
}
