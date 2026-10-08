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
    final loan = ReminderLoan(
      loanId: 'l1',
      clientName: 'Fulano',
      remainingCents: 34500,
      dueDate: DateTime.utc(2026, 11, 7),
    );

    test('agenda 7, 3, 1 dia antes, no dia e 1 dia depois às 9h', () {
      final plan = ReminderPlanner.plan([loan], now: DateTime(2026, 10, 1, 10));
      expect(plan.map((r) => r.at), [
        DateTime(2026, 10, 31, 9),
        DateTime(2026, 11, 4, 9),
        DateTime(2026, 11, 6, 9),
        DateTime(2026, 11, 7, 9),
        DateTime(2026, 11, 8, 9),
      ]);
      expect(plan.first.body, r'Fulano possui R$ 345,00 a receber em 7 dias.');
      expect(plan[3].title, 'Operação vence hoje');
    });

    test('não agenda horários passados nem operações quitadas', () {
      final plan = ReminderPlanner.plan([
        loan,
        ReminderLoan(loanId: 'l2', clientName: 'Pago', remainingCents: 0, dueDate: DateTime.utc(2026, 11, 7)),
      ], now: DateTime(2026, 11, 6, 10));
      expect(plan.length, 2);
      expect(plan.every((r) => r.loanId == 'l1'), isTrue);
    });

    test('ocultar valores remove o valor do texto', () {
      final plan = ReminderPlanner.plan([loan], now: DateTime(2026, 10, 1), hideAmounts: true);
      expect(plan.any((r) => r.body.contains(r'R$')), isFalse);
    });

    test('respeita o limite de lembretes', () {
      final many = [
        for (var i = 0; i < 200; i++)
          ReminderLoan(
            loanId: '$i',
            clientName: 'C$i',
            remainingCents: 100,
            dueDate: DateTime.utc(2026, 12, 1 + i % 28),
          ),
      ];
      final plan = ReminderPlanner.plan(many, now: DateTime(2026, 10, 1));
      expect(plan.length, ReminderPlanner.maxReminders);
      expect(plan.map((r) => r.id).toSet().length, plan.length);
    });
  });
}
