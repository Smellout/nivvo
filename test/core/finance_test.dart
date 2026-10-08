import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nivvo/core/finance/loan_calculator.dart';
import 'package:nivvo/core/money/money.dart';
import 'package:nivvo/core/utils/dates.dart';
import 'package:nivvo/core/utils/validators.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Exemplos da especificação', () {
    test('R\$ 300 a 15% por 30 dias a partir de 08/10/2026', () {
      final q = LoanCalculator.quote(
        principalCents: 30000,
        rateHundredths: 1500,
        termDays: 30,
        startDate: DateTime.utc(2026, 10, 8),
      );
      expect(q.interestCents, 4500);
      expect(q.totalCents, 34500);
      expect(q.dueDate, DateTime.utc(2026, 11, 7));
    });

    test('saldo com encargos 20 + 15 + 25 e pagamento de 100 = 305', () {
      final balance = LoanCalculator.balance(
        principalCents: 30000,
        interestCents: 4500,
        chargesCents: 2000 + 1500 + 2500,
        paidCents: 10000,
      );
      expect(balance, 30500);
    });

    test('extrato: 300 + 45 + 30 − 100 = 275', () {
      expect(
        LoanCalculator.balance(principalCents: 30000, interestCents: 4500, chargesCents: 3000, paidCents: 10000),
        27500,
      );
    });

    test('pagamento parcial de 100 sobre saldo de 405 deixa 305', () {
      const total = 30000 + 4500 + 6000;
      expect(total, 40500);
      expect(total - 10000, 30500);
    });
  });

  group('Juros', () {
    test('arredonda meio centavo para cima (igual ao round do Postgres)', () {
      // 333,33 × 12,5% = 41,66625 -> 41,67
      expect(LoanCalculator.interest(33333, 1250), 4167);
      // 0,10 × 15% = 0,015 -> 0,02
      expect(LoanCalculator.interest(10, 1500), 2);
      // 0,10 × 14% = 0,014 -> 0,01
      expect(LoanCalculator.interest(10, 1400), 1);
    });

    test('taxa zero não gera juros', () {
      expect(LoanCalculator.interest(50000, 0), 0);
    });

    test('valores grandes não estouram', () {
      expect(LoanCalculator.interest(99999999999, 99999), 999989999990);
    });
  });

  group('Vencimento', () {
    test('atravessa mês, ano e horário de verão sem erro', () {
      expect(LoanCalculator.dueDate(DateTime.utc(2026, 12, 20), 15), DateTime.utc(2027, 1, 4));
      expect(LoanCalculator.dueDate(DateTime.utc(2028, 2, 15), 15), DateTime.utc(2028, 3, 1));
      expect(LoanCalculator.dueDate(DateTime.utc(2026, 1, 31), 30), DateTime.utc(2026, 3, 2));
    });
  });

  group('Alocação do pagamento (encargos → juros → principal)', () {
    test('pagamento parcial cobre encargos e parte dos juros', () {
      final a = LoanCalculator.allocate(
        paidCents: 8000,
        principalCents: 30000,
        interestCents: 4500,
        chargesCents: 6000,
      );
      expect(a.chargesCents, 6000);
      expect(a.interestCents, 2000);
      expect(a.principalCents, 0);
      expect(a.earningsCents, 8000);
    });

    test('quitação aloca tudo', () {
      final a = LoanCalculator.allocate(
        paidCents: 40500,
        principalCents: 30000,
        interestCents: 4500,
        chargesCents: 6000,
      );
      expect(a.principalCents, 30000);
      expect(a.earningsCents, 10500);
    });
  });

  group('Status exibido', () {
    final today = DateTime.utc(2026, 11, 7);

    LoanDisplayStatus status({
      LoanLifecycle lifecycle = LoanLifecycle.active,
      int remaining = 34500,
      int paid = 0,
      required DateTime due,
    }) => LoanStatusRules.resolve(
      lifecycle: lifecycle,
      remainingCents: remaining,
      paidCents: paid,
      dueDate: due,
      today: today,
    );

    test('regras básicas', () {
      expect(status(due: DateTime.utc(2026, 11, 30)), LoanDisplayStatus.pending);
      expect(status(due: DateTime.utc(2026, 11, 9)), LoanDisplayStatus.dueSoon);
      expect(status(due: today), LoanDisplayStatus.dueToday);
      expect(status(due: DateTime.utc(2026, 11, 6)), LoanDisplayStatus.overdue);
      expect(status(due: DateTime.utc(2026, 11, 30), paid: 10000, remaining: 24500), LoanDisplayStatus.partial);
    });

    test('vencida tem precedência sobre pagamento parcial', () {
      expect(status(due: DateTime.utc(2026, 11, 1), paid: 10000, remaining: 24500), LoanDisplayStatus.overdue);
    });

    test('saldo zero é Paga; cancelada vence tudo', () {
      expect(
        status(due: DateTime.utc(2026, 11, 1), remaining: 0, lifecycle: LoanLifecycle.paid),
        LoanDisplayStatus.paid,
      );
      expect(status(due: DateTime.utc(2026, 11, 1), lifecycle: LoanLifecycle.cancelled), LoanDisplayStatus.cancelled);
    });
  });

  group('Money / Rate', () {
    test('parse e JSON sem ponto flutuante', () {
      expect(Money.parse('300.10'), 30010);
      expect(Money.parse('300,1'), 30010);
      expect(Money.parse('0.29'), 29);
      expect(Money.fromJson(300.1), 30010);
      expect(Money.fromJson(0.29), 29);
      expect(Money.fromJson('345.00'), 34500);
      expect(Money.toJson(34500), 345);
      expect(Money.toJson(30010), 300.1);
    });

    test('formatação brasileira', () {
      expect(Money.format(1245000), r'R$ 12.450,00');
      expect(Money.formatSigned(-10000), r'− R$ 100,00');
      expect(Money.formatSigned(4500), r'+ R$ 45,00');
    });

    test('taxa', () {
      expect(Rate.parse('15'), 1500);
      expect(Rate.parse('12,5'), 1250);
      expect(Rate.parse('12.75'), 1275);
      expect(Rate.parse('1234'), isNull);
      expect(Rate.format(1500), '15%');
      expect(Rate.format(1250), '12,5%');
      expect(Rate.format(1205), '12,05%');
      expect(Rate.fromJson(15), 1500);
      expect(Rate.fromJson(12.5), 1250);
    });
  });

  group('Datas', () {
    test('textos relativos', () {
      final today = DateTime.utc(2026, 11, 5);
      expect(Dates.relativeDue(DateTime.utc(2026, 11, 5), today), 'Vence hoje');
      expect(Dates.relativeDue(DateTime.utc(2026, 11, 6), today), 'Vence amanhã');
      expect(Dates.relativeDue(DateTime.utc(2026, 11, 7), today), 'Vence em 2 dias');
      expect(Dates.relativeDue(DateTime.utc(2026, 11, 4), today), 'Venceu ontem');
      expect(Dates.relativeDue(DateTime.utc(2026, 11, 1), today), 'Venceu há 4 dias');
    });

    test('parse/serialização do tipo date', () {
      expect(Dates.parse('2026-11-07'), DateTime.utc(2026, 11, 7));
      expect(Dates.toJson(DateTime.utc(2026, 1, 2)), '2026-01-02');
    });
  });

  group('Validações', () {
    test('CPF', () {
      expect(Validators.isValidCpf('52998224725'), isTrue);
      expect(Validators.isValidCpf('11111111111'), isFalse);
      expect(Validators.isValidCpf('52998224724'), isFalse);
      expect(Validators.cpf('529.982.247-25'), isNull);
      expect(Validators.cpf(''), isNull);
    });

    test('telefone', () {
      expect(Validators.phone('(11) 98765-4321'), isNull);
      expect(Validators.phone('1234'), isNotNull);
      expect(Formatters.phone('11987654321'), '(11) 98765-4321');
    });
  });
}
