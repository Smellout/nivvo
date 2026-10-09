import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nivvo/core/errors/app_exception.dart';
import 'package:nivvo/core/finance/loan_calculator.dart';
import 'package:nivvo/demo/demo_store.dart';
import 'package:nivvo/shared/models/payment.dart';
import 'package:nivvo/shared/repositories/loans_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  final today = DateTime.utc(2026, 10, 9);

  test('dados de exemplo reproduzem o caso da especificação (saldo 305)', () {
    final store = DemoStore(today: today);
    final fulano = store.loans(filter: LoanFilter.overdue, today: today, query: 'fulano').single;
    expect(fulano.principalCents, 30000);
    expect(fulano.interestCents, 4500);
    expect(fulano.chargesCents, 6000);
    expect(fulano.paidCents, 10000);
    expect(fulano.remainingCents, 30500);
  });

  test('painel coerente com as operações', () {
    final store = DemoStore(today: today);
    final d = store.dashboard();
    final active = store.loans(filter: LoanFilter.all, today: today).where((l) => l.isActive);
    expect(d.toReceiveCents, active.fold<int>(0, (s, l) => s + l.remainingCents));
    expect(d.overdueCount, 2);
    expect(d.dueTodayCount, 1);
    expect(d.principalOutstandingCents, lessThanOrEqualTo(d.toReceiveCents));
  });

  test('mesmas regras do banco: quitação, bloqueio de excesso e estorno', () {
    final store = DemoStore(today: today);
    final loan = store.loans(filter: LoanFilter.dueSoon, today: today, query: 'joão').single;

    expect(
      () => store.registerPayment(
        loanId: loan.id,
        amountCents: loan.remainingCents + 1,
        method: PaymentMethod.pix,
        date: today,
      ),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('maior que o saldo'))),
    );

    store.registerPayment(loanId: loan.id, amountCents: loan.remainingCents, method: PaymentMethod.pix, date: today);
    var detail = store.detail(loan.id);
    expect(detail.loan.lifecycle, LoanLifecycle.paid);

    store.cancelPayment(detail.payments.single.id, 'valor errado');
    detail = store.detail(loan.id);
    expect(detail.loan.lifecycle, LoanLifecycle.active);
    expect(detail.loan.remainingCents, loan.remainingCents);
  });
}
