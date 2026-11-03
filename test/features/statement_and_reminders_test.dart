import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nivvo/core/finance/loan_calculator.dart';
import 'package:nivvo/features/loans/loan_statement.dart';
import 'package:nivvo/features/notifications/reminder_planner.dart';
import 'package:nivvo/shared/models/charge.dart';
import 'package:nivvo/shared/models/history_entry.dart';
import 'package:nivvo/shared/models/loan.dart';
import 'package:nivvo/shared/models/payment.dart';

Loan _loan({int charges = 0, int paid = 0, LoanLifecycle lifecycle = LoanLifecycle.active}) => Loan(
  id: 'l1',
  clientId: 'c1',
  clientName: 'Fulano da Silva',
  principalCents: 30000,
  rateHundredths: 1500,
  interestCents: 4500,
  chargesCents: charges,
  paidCents: paid,
  remainingCents: 34500 + charges - paid,
  earningsReceivedCents: 0,
  termDays: 30,
  startDate: DateTime.utc(2026, 10, 8),
  dueDate: DateTime.utc(2026, 11, 7),
  lifecycle: lifecycle,
  createdAt: DateTime.utc(2026, 10, 8, 12),
);

LoanCharge _charge(String id, int cents, DateTime date, {bool active = true}) => LoanCharge(
  id: id,
  loanId: 'l1',
  type: ChargeType.lateInterest,
  amountCents: cents,
  chargeDate: date,
  isActive: active,
  createdAt: date,
);

Payment _payment(String id, int cents, DateTime date, {bool active = true}) => Payment(
  id: id,
  loanId: 'l1',
  amountCents: cents,
  method: PaymentMethod.pix,
  paymentDate: date,
  isActive: active,
  createdAt: date,
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Extrato', () {
    test('ignora encargos cancelados e pagamentos estornados', () {
      final detail = LoanDetail(
        loan: _loan(charges: 6000, paid: 10000),
        charges: [
          _charge('a', 2000, DateTime.utc(2026, 11, 8)),
          _charge('b', 1500, DateTime.utc(2026, 11, 12)),
          _charge('x', 9900, DateTime.utc(2026, 11, 13), active: false),
          _charge('c', 2500, DateTime.utc(2026, 11, 15)),
        ],
        payments: [
          _payment('p', 10000, DateTime.utc(2026, 11, 12)),
          _payment('q', 5000, DateTime.utc(2026, 11, 14), active: false),
        ],
        history: const [],
      );
      final s = LoanStatementBuilder.statement(detail);
      expect(s.balanceCents, 30500);
      expect(s.lines.length, 2 + 3 + 1);
      expect(s.lines.first.kind, StatementKind.principal);
      expect(s.lines.where((l) => l.kind == StatementKind.payment).single.cents, -10000);
    });
  });

  group('Linha do tempo', () {
    test('mostra vencimento e marca vencida quando passou a data', () {
      final detail = LoanDetail(
        loan: _loan(),
        charges: const [],
        payments: const [],
        history: [
          HistoryEntry(
            id: 'h1',
            action: HistoryAction.loanCreated,
            amountCents: 30000,
            eventDate: DateTime.utc(2026, 10, 8),
            metadata: const {'interest_rate': 15, 'interest_amount': 45},
            createdAt: DateTime.utc(2026, 10, 8, 12),
          ),
        ],
      );
      final events = LoanStatementBuilder.timeline(detail, DateTime.utc(2026, 11, 10));
      expect(events.map((e) => e.title), [
        'Operação criada',
        'Juros da operação · 15%',
        'Vencimento',
        'Operação vencida',
      ]);
      expect(events[1].amountText, r'+ R$ 45,00');
    });
  });

  group('Lembretes', () {
    ReminderLoan loan(String id, String name, int cents, DateTime due) =>
        ReminderLoan(loanId: id, clientName: name, remainingCents: cents, dueDate: due);

    final fulano = loan('l1', 'Fulano', 34500, DateTime.utc(2026, 11, 7));

    test('avisa às 9h de 3 dias antes até o dia, e no dia seguinte ao vencimento', () {
      final plan = ReminderPlanner.plan([fulano], now: DateTime(2026, 10, 1, 10));
      expect(plan.map((r) => (r.at, r.route)), [
        (DateTime(2026, 11, 4, 9), ReminderPlanner.dueSoonRoute),
        (DateTime(2026, 11, 5, 9), ReminderPlanner.dueSoonRoute),
        (DateTime(2026, 11, 6, 9), ReminderPlanner.dueSoonRoute),
        (DateTime(2026, 11, 7, 9), ReminderPlanner.dueSoonRoute),
        (DateTime(2026, 11, 8, 9), ReminderPlanner.overdueRoute),
      ]);
      expect(plan.first.title, 'Você tem operações chegando no prazo!');
      expect(plan.first.body, r'A operação de Fulano vence em 3 dias — R$ 345,00 a receber.');
      expect(plan[2].body, contains('vence amanhã'));
      expect(plan[3].body, contains('vence hoje'));
      expect(plan[4].body, r'A operação de Fulano venceu ontem — R$ 345,00 a receber.');
    });

    test('junta várias operações em um único aviso por dia', () {
      final plan = ReminderPlanner.plan([
        fulano,
        loan('l2', 'Maria', 80000, DateTime.utc(2026, 11, 6)),
      ], now: DateTime(2026, 11, 5, 8));
      final today = plan.where((r) => r.at == DateTime(2026, 11, 5, 9)).toList();
      expect(today, hasLength(1));
      expect(today.single.body, r'2 operações vencem em até 3 dias — R$ 1.145,00 a receber. Toque para ver.');
      expect(plan.map((r) => r.id).toSet().length, plan.length);
    });

    test('não agenda horários passados nem operações quitadas', () {
      final plan = ReminderPlanner.plan([
        fulano,
        loan('l2', 'Pago', 0, DateTime.utc(2026, 11, 7)),
      ], now: DateTime(2026, 11, 6, 10));
      expect(plan.map((r) => r.at), [DateTime(2026, 11, 7, 9), DateTime(2026, 11, 8, 9)]);
      expect(plan.any((r) => r.body.contains('Pago')), isFalse);
    });

    test('ocultar valores remove o valor do texto', () {
      final plan = ReminderPlanner.plan([fulano], now: DateTime(2026, 10, 1), hideAmounts: true);
      expect(plan, isNotEmpty);
      expect(plan.any((r) => r.body.contains(r'R$')), isFalse);
    });

    test('limita o agendamento ao horizonte', () {
      final plan = ReminderPlanner.plan([
        for (var i = 0; i < 200; i++) loan('$i', 'C$i', 100, DateTime.utc(2026, 10, 1 + i)),
      ], now: DateTime(2026, 10, 1, 10));
      expect(plan.last.at.isBefore(DateTime(2026, 10, 1 + ReminderPlanner.horizonDays + 1)), isTrue);
      expect(plan.length, lessThanOrEqualTo(2 * (ReminderPlanner.horizonDays + 1)));
    });
  });
}
