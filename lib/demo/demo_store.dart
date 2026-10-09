import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../core/errors/app_exception.dart';
import '../core/finance/loan_calculator.dart';
import '../core/money/money.dart';
import '../core/utils/dates.dart';
import '../core/utils/validators.dart';
import '../shared/models/charge.dart';
import '../shared/models/client.dart';
import '../shared/models/history_entry.dart';
import '../shared/models/loan.dart';
import '../shared/models/payment.dart';
import '../shared/models/summaries.dart';
import '../shared/repositories/loans_repository.dart';

/// Banco em memória do modo demonstração. Reproduz as regras das funções SQL
/// (`create_loan`, `register_payment`, `cancel_charge`…) com os mesmos códigos de erro.
class DemoStore {
  DemoStore({DateTime? today}) : today = today ?? Dates.today() {
    _seed();
  }

  final DateTime today;
  final _clients = <String, Client>{};
  final _touched = <String, DateTime>{};
  final _loans = <String, _DemoLoan>{};
  var _seq = 0;
  bool _seeding = false;

  String _id(String prefix) => '$prefix-${++_seq}';

  Never _fail(String code) => throw AppException.from(PostgrestException(message: code));

  DateTime _stamp(DateTime eventDate) =>
      _seeding ? DateTime.utc(eventDate.year, eventDate.month, eventDate.day, 12, 0, _seq) : DateTime.now().toUtc();

  // ------------------------------------------------------------------ clientes

  Client createClient(ClientInput input) {
    final json = input.toJson();
    final name = json['name'] as String;
    if (Validators.name(name) != null) throw const AppException('Informe o nome do cliente.');
    final cpf = json['cpf'] as String?;
    if (cpf != null && _clients.values.any((c) => c.cpf == cpf)) {
      throw AppException.from(const PostgrestException(message: 'duplicate key value (cpf)', code: '23505'));
    }
    final client = Client(
      id: _id('client'),
      name: name,
      phone: json['phone'] as String?,
      cpf: cpf,
      notes: json['notes'] as String?,
      createdAt: _stamp(today),
    );
    _clients[client.id] = client;
    _touched[client.id] = DateTime.now();
    return client;
  }

  Client updateClient(String id, ClientInput input) {
    final current = _clients[id] ?? _fail('client_not_found');
    final json = input.toJson();
    final cpf = json['cpf'] as String?;
    if (cpf != null && _clients.values.any((c) => c.cpf == cpf && c.id != id)) {
      throw AppException.from(const PostgrestException(message: 'duplicate key value (cpf)', code: '23505'));
    }
    final updated = Client(
      id: id,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      cpf: cpf,
      notes: json['notes'] as String?,
      createdAt: current.createdAt,
    );
    _clients[id] = updated;
    _touched[id] = DateTime.now();
    return updated;
  }

  ClientSummary clientSummary(String id) {
    final client = _clients[id] ?? _fail('client_not_found');
    final loans = _loans.values.where((l) => l.clientId == id);
    final valid = loans.where((l) => l.status != LoanLifecycle.cancelled);
    final active = loans.where((l) => l.status == LoanLifecycle.active);
    return ClientSummary(
      client: client,
      totalLentCents: valid.fold(0, (s, l) => s + l.principal),
      totalReceivedCents: valid.fold(0, (s, l) => s + l.paidCents),
      balanceCents: active.fold(0, (s, l) => s + l.remaining),
      loansCount: valid.length,
      overdueCount: active.where((l) => l.due.isBefore(today)).length,
    );
  }

  List<ClientSummary> clients({String query = '', int offset = 0, int limit = 30}) {
    final q = _normalize(query);
    final digits = Validators.digitsOnly(query);
    final list = _clients.values.where((c) {
      if (q.isEmpty) return true;
      if (_normalize(c.name).contains(q)) return true;
      return digits.length >= 3 && ((c.phone ?? '').contains(digits) || (c.cpf ?? '').contains(digits));
    }).toList()..sort((a, b) => _normalize(a.name).compareTo(_normalize(b.name)));
    return list.skip(offset).take(limit).map((c) => clientSummary(c.id)).toList();
  }

  List<Client> recentClients({int limit = 8}) {
    final list = _clients.values.toList()
      ..sort((a, b) => (_touched[b.id] ?? b.createdAt).compareTo(_touched[a.id] ?? a.createdAt));
    return list.take(limit).toList();
  }

  // ------------------------------------------------------------------ operações

  String createLoan({required String clientId, required LoanQuote quote, String? notes}) {
    if (!_clients.containsKey(clientId)) _fail('client_not_found');
    if (quote.principalCents <= 0) _fail('invalid_amount');
    if (quote.rateHundredths < 0 || quote.rateHundredths > LoanCalculator.maxRateHundredths) _fail('invalid_rate');
    if (quote.termDays < 1 || quote.termDays > LoanCalculator.maxTermDays) _fail('invalid_term');
    if (quote.startDate.isAfter(Dates.addDays(today, 1))) _fail('invalid_date');

    final loan = _DemoLoan(
      id: _id('loan'),
      clientId: clientId,
      principal: quote.principalCents,
      rate: quote.rateHundredths,
      interest: LoanCalculator.interest(quote.principalCents, quote.rateHundredths),
      termDays: quote.termDays,
      start: quote.startDate,
      due: LoanCalculator.dueDate(quote.startDate, quote.termDays),
      notes: notes,
      createdAt: _stamp(quote.startDate),
    );
    _loans[loan.id] = loan;
    _touched[clientId] = DateTime.now();
    _history(
      loan,
      HistoryAction.loanCreated,
      quote.startDate,
      amount: loan.principal,
      metadata: {
        'interest_rate': Rate.toJson(loan.rate),
        'interest_amount': Money.toJson(loan.interest),
        'term_days': loan.termDays,
        'due_date': Dates.toJson(loan.due),
      },
    );
    return loan.id;
  }

  void addCharge({
    required String loanId,
    required ChargeType type,
    required int amountCents,
    required DateTime date,
    String? description,
  }) {
    final loan = _loans[loanId] ?? _fail('loan_not_found');
    if (loan.status == LoanLifecycle.cancelled) _fail('loan_cancelled');
    if (loan.status == LoanLifecycle.paid) _fail('loan_already_paid');
    if (amountCents <= 0) _fail('invalid_amount');
    _checkDate(loan, date);

    final charge = LoanCharge(
      id: _id('charge'),
      loanId: loanId,
      type: type,
      amountCents: amountCents,
      description: _blank(description),
      chargeDate: date,
      isActive: true,
      createdAt: _stamp(date),
    );
    loan.charges.add(charge);
    _history(
      loan,
      HistoryAction.chargeAdded,
      date,
      amount: amountCents,
      description: charge.description,
      metadata: {'charge_id': charge.id, 'type': type.json},
    );
  }

  void cancelCharge(String chargeId, String reason) {
    if (reason.trim().length < 3) _fail('reason_required');
    final loan =
        _loans.values.where((l) => l.charges.any((c) => c.id == chargeId)).firstOrNull ?? _fail('charge_not_found');
    final index = loan.charges.indexWhere((c) => c.id == chargeId);
    final charge = loan.charges[index];
    if (!charge.isActive) _fail('already_cancelled');
    if (loan.status == LoanLifecycle.cancelled) _fail('loan_cancelled');
    if (loan.remaining - charge.amountCents < 0) _fail('balance_would_be_negative');

    loan.charges[index] = LoanCharge(
      id: charge.id,
      loanId: charge.loanId,
      type: charge.type,
      amountCents: charge.amountCents,
      description: charge.description,
      chargeDate: charge.chargeDate,
      isActive: false,
      cancelledAt: DateTime.now().toUtc(),
      cancelReason: reason.trim(),
      createdAt: charge.createdAt,
    );
    _history(
      loan,
      HistoryAction.chargeCancelled,
      today,
      amount: charge.amountCents,
      description: reason.trim(),
      metadata: {'charge_id': charge.id, 'type': charge.type.json},
    );
    if (loan.status == LoanLifecycle.active && loan.remaining == 0) _settle(loan, today);
  }

  void registerPayment({
    required String loanId,
    required int amountCents,
    required PaymentMethod method,
    required DateTime date,
    String? notes,
  }) {
    final loan = _loans[loanId] ?? _fail('loan_not_found');
    if (loan.status == LoanLifecycle.cancelled) _fail('loan_cancelled');
    if (loan.status == LoanLifecycle.paid) _fail('loan_already_paid');
    if (amountCents <= 0) _fail('invalid_amount');
    if (amountCents > loan.remaining) _fail('amount_exceeds_balance');
    _checkDate(loan, date);

    final settles = loan.remaining - amountCents == 0;
    final payment = Payment(
      id: _id('payment'),
      loanId: loanId,
      amountCents: amountCents,
      method: method,
      paymentDate: date,
      notes: _blank(notes),
      isActive: true,
      createdAt: _stamp(date),
    );
    loan.payments.add(payment);
    _history(
      loan,
      HistoryAction.paymentRegistered,
      date,
      amount: amountCents,
      description: payment.notes,
      metadata: {'payment_id': payment.id, 'method': method.json, 'settled': settles},
    );
    if (settles) _settle(loan, date);
  }

  void cancelPayment(String paymentId, String reason) {
    if (reason.trim().length < 3) _fail('reason_required');
    final loan =
        _loans.values.where((l) => l.payments.any((p) => p.id == paymentId)).firstOrNull ?? _fail('payment_not_found');
    final index = loan.payments.indexWhere((p) => p.id == paymentId);
    final payment = loan.payments[index];
    if (!payment.isActive) _fail('already_cancelled');
    if (loan.status == LoanLifecycle.cancelled) _fail('loan_cancelled');

    final wasPaid = loan.status == LoanLifecycle.paid;
    loan.payments[index] = Payment(
      id: payment.id,
      loanId: payment.loanId,
      amountCents: payment.amountCents,
      method: payment.method,
      paymentDate: payment.paymentDate,
      notes: payment.notes,
      isActive: false,
      cancelledAt: DateTime.now().toUtc(),
      cancelReason: reason.trim(),
      createdAt: payment.createdAt,
    );
    loan
      ..status = LoanLifecycle.active
      ..paidAt = null;
    _history(
      loan,
      HistoryAction.paymentCancelled,
      today,
      amount: payment.amountCents,
      description: reason.trim(),
      metadata: {'payment_id': payment.id, 'method': payment.method.json},
    );
    if (wasPaid) _history(loan, HistoryAction.loanReopened, today);
  }

  void cancelLoan(String loanId, String reason) {
    if (reason.trim().length < 3) _fail('reason_required');
    final loan = _loans[loanId] ?? _fail('loan_not_found');
    if (loan.status == LoanLifecycle.cancelled) _fail('already_cancelled');
    if (loan.paidCents > 0) _fail('loan_has_payments');
    loan
      ..status = LoanLifecycle.cancelled
      ..cancelledAt = DateTime.now().toUtc()
      ..cancelReason = reason.trim();
    _history(loan, HistoryAction.loanCancelled, today, description: reason.trim());
  }

  // ------------------------------------------------------------------ leituras

  Loan _view(_DemoLoan l) {
    final client = _clients[l.clientId]!;
    final earnings = l.interest + l.chargesCents;
    return Loan(
      id: l.id,
      clientId: l.clientId,
      clientName: client.name,
      clientPhone: client.phone,
      principalCents: l.principal,
      rateHundredths: l.rate,
      interestCents: l.interest,
      chargesCents: l.chargesCents,
      paidCents: l.paidCents,
      remainingCents: l.remaining,
      earningsReceivedCents: l.paidCents < earnings ? l.paidCents : earnings,
      termDays: l.termDays,
      startDate: l.start,
      dueDate: l.due,
      lifecycle: l.status,
      notes: l.notes,
      paidAt: l.paidAt,
      cancelledAt: l.cancelledAt,
      cancelReason: l.cancelReason,
      createdAt: l.createdAt,
    );
  }

  LoanDetail detail(String loanId) {
    final l = _loans[loanId] ?? _fail('loan_not_found');
    return LoanDetail(
      loan: _view(l),
      charges: [...l.charges]..sort((a, b) => a.chargeDate.compareTo(b.chargeDate)),
      payments: [...l.payments]..sort((a, b) => a.paymentDate.compareTo(b.paymentDate)),
      history: [...l.history],
    );
  }

  List<Loan> loans({
    required LoanFilter filter,
    required DateTime today,
    String query = '',
    String? clientId,
    int offset = 0,
    int limit = 25,
  }) {
    final q = _normalize(query);
    final digits = Validators.digitsOnly(query);
    final soon = Dates.addDays(today, LoanStatusRules.dueSoonDays);
    var list = _loans.values.map(_view).where((l) {
      if (clientId != null && l.clientId != clientId) return false;
      final active = l.lifecycle == LoanLifecycle.active;
      final ok = switch (filter) {
        LoanFilter.all => true,
        LoanFilter.pending => active && !l.dueDate.isBefore(today),
        LoanFilter.dueSoon => active && !l.dueDate.isBefore(today) && !l.dueDate.isAfter(soon),
        LoanFilter.overdue => active && l.dueDate.isBefore(today),
        LoanFilter.paid => l.lifecycle == LoanLifecycle.paid,
      };
      if (!ok) return false;
      if (q.isEmpty) return true;
      if (_normalize(l.clientName).contains(q)) return true;
      final c = _clients[l.clientId]!;
      return digits.length >= 3 && ((c.phone ?? '').contains(digits) || (c.cpf ?? '').contains(digits));
    }).toList();

    list.sort((a, b) {
      final primary = switch (filter) {
        LoanFilter.paid => (b.paidAt ?? b.createdAt).compareTo(a.paidAt ?? a.createdAt),
        LoanFilter.all =>
          a.lifecycle.index != b.lifecycle.index
              ? a.lifecycle.index.compareTo(b.lifecycle.index)
              : a.dueDate.compareTo(b.dueDate),
        _ => a.dueDate.compareTo(b.dueDate),
      };
      return primary != 0 ? primary : b.createdAt.compareTo(a.createdAt);
    });
    list = list.skip(offset).take(limit).toList();
    return list;
  }

  List<Loan> upcoming(DateTime today, {int limit = 6}) {
    final list =
        _loans.values.where((l) => l.status == LoanLifecycle.active && !l.due.isBefore(today)).map(_view).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list.take(limit).toList();
  }

  List<Loan> activeDueBetween(DateTime from, DateTime until) => _loans.values
      .where((l) => l.status == LoanLifecycle.active && !l.due.isBefore(from) && !l.due.isAfter(until))
      .map(_view)
      .toList();

  DashboardSummary dashboard() {
    final all = _loans.values;
    final active = all.where((l) => l.status == LoanLifecycle.active).toList();
    final valid = all.where((l) => l.status != LoanLifecycle.cancelled).toList();
    final overdue = active.where((l) => l.due.isBefore(today)).toList();
    final soon = Dates.addDays(today, LoanStatusRules.dueSoonDays);
    final monthStart = DateTime.utc(today.year, today.month, 1);

    int principalOutstanding(_DemoLoan l) {
      final a = LoanCalculator.allocate(
        paidCents: l.paidCents,
        principalCents: l.principal,
        interestCents: l.interest,
        chargesCents: l.chargesCents,
      );
      return l.principal - a.principalCents;
    }

    return DashboardSummary(
      toReceiveCents: active.fold(0, (s, l) => s + l.remaining),
      principalOutstandingCents: active.fold(0, (s, l) => s + principalOutstanding(l)),
      activeCount: active.length,
      overdueCount: overdue.length,
      overdueCents: overdue.fold(0, (s, l) => s + l.remaining),
      dueTodayCount: active.where((l) => l.due == today).length,
      dueSoonCount: active.where((l) => l.due.isAfter(today) && !l.due.isAfter(soon)).length,
      totalLentCents: valid.fold(0, (s, l) => s + l.principal),
      totalReceivedCents: valid.fold(0, (s, l) => s + l.paidCents),
      earningsReceivedCents: valid.fold(0, (s, l) => s + _view(l).earningsReceivedCents),
      receivedThisMonthCents: all
          .expand((l) => l.payments)
          .where((p) => p.isActive && !p.paymentDate.isBefore(monthStart) && !p.paymentDate.isAfter(today))
          .fold(0, (s, p) => s + p.amountCents),
    );
  }

  ReportSummary report(DateTime from, DateTime to) {
    bool inRange(DateTime d) => !d.isBefore(from) && !d.isAfter(to);
    final valid = _loans.values.where((l) => l.status != LoanLifecycle.cancelled);
    final started = valid.where((l) => inRange(l.start)).toList();
    final payments = _loans.values
        .expand((l) => l.payments)
        .where((p) => p.isActive && inRange(p.paymentDate))
        .toList();
    final charges = _loans.values.expand((l) => l.charges).where((c) => c.isActive && inRange(c.chargeDate));
    final active = _loans.values.where((l) => l.status == LoanLifecycle.active);
    final byDay = <DateTime, int>{};
    for (final p in payments) {
      byDay[p.paymentDate] = (byDay[p.paymentDate] ?? 0) + p.amountCents;
    }
    final days = byDay.keys.toList()..sort();
    return ReportSummary(
      from: from,
      to: to,
      totalLentCents: started.fold(0, (s, l) => s + l.principal),
      totalInterestCents: started.fold(0, (s, l) => s + l.interest),
      loansCount: started.length,
      totalChargesCents: charges.fold(0, (s, c) => s + c.amountCents),
      totalReceivedCents: payments.fold(0, (s, p) => s + p.amountCents),
      paymentsCount: payments.length,
      totalPendingCents: active.fold(0, (s, l) => s + l.remaining),
      totalOverdueCents: active.where((l) => l.due.isBefore(today)).fold(0, (s, l) => s + l.remaining),
      series: [for (final d in days) DailyAmount(d, byDay[d]!)],
    );
  }

  // ------------------------------------------------------------------ internos

  void _checkDate(_DemoLoan loan, DateTime date) {
    if (date.isBefore(loan.start) || date.isAfter(Dates.addDays(today, 1))) _fail('invalid_date');
  }

  void _settle(_DemoLoan loan, DateTime date) {
    loan
      ..status = LoanLifecycle.paid
      ..paidAt = _stamp(date);
    _history(loan, HistoryAction.loanPaid, date);
  }

  void _history(
    _DemoLoan loan,
    HistoryAction action,
    DateTime date, {
    int? amount,
    String? description,
    Map<String, dynamic> metadata = const {},
  }) {
    loan.history.add(
      HistoryEntry(
        id: _id('history'),
        action: action,
        amountCents: amount,
        eventDate: date,
        description: description,
        metadata: metadata,
        createdAt: _stamp(date),
      ),
    );
  }

  static String? _blank(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

  static String _normalize(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    final lower = s.toLowerCase().trim();
    final out = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      out.write(i >= 0 ? to[i] : ch);
    }
    return out.toString();
  }

  // ------------------------------------------------------------------ dados de exemplo

  void _seed() {
    _seeding = true;
    final t = today;
    DateTime d(int offset) => Dates.addDays(t, offset);

    String client(String name, String phone, [String? cpf]) =>
        createClient(ClientInput(name: name, phone: phone, cpf: cpf)).id;

    String loan(String clientId, int reais, int ratePct, int term, int startOffset) => createLoan(
      clientId: clientId,
      quote: LoanCalculator.quote(
        principalCents: reais * 100,
        rateHundredths: ratePct * 100,
        termDays: term,
        startDate: d(startOffset),
      ),
    );

    void pay(String loanId, int reais, PaymentMethod m, int offset) =>
        registerPayment(loanId: loanId, amountCents: reais * 100, method: m, date: d(offset));

    void charge(String loanId, ChargeType type, int reais, int offset, [String? desc]) =>
        addCharge(loanId: loanId, type: type, amountCents: reais * 100, date: d(offset), description: desc);

    final fulano = client('Fulano da Silva', '11987654321', '52998224725');
    final joao = client('João Souza', '11991234567');
    final maria = client('Maria Oliveira', '21988776655');
    final ana = client('Ana Costa', '31977665544');
    final carlos = client('Carlos Pereira', '11966554433');
    final beatriz = client('Beatriz Lima', '41955443322');
    final rafael = client('Rafael Santos', '51944332211');
    final juliana = client('Juliana Alves', '61933221100');
    final pedro = client('Pedro Rocha', '71922110099');

    // O exemplo da especificação: 300 + 45 + encargos 60 − pagamento 100 = 305.
    final l1 = loan(fulano, 300, 15, 30, -38);
    charge(l1, ChargeType.lateInterest, 20, -7);
    pay(l1, 100, PaymentMethod.pix, -4);
    charge(l1, ChargeType.lateInterest, 15, -3);
    charge(l1, ChargeType.fine, 25, -1, 'Multa combinada');

    loan(maria, 800, 15, 30, -30); // vence hoje
    loan(joao, 500, 15, 30, -29); // vence amanhã
    final l4 = loan(ana, 1200, 10, 30, -28); // vence em 2 dias, parcial
    pay(l4, 400, PaymentMethod.transfer, -10);
    loan(carlos, 750, 15, 30, -27); // vence em 3 dias
    loan(carlos, 2000, 12, 45, -10);
    loan(beatriz, 650, 20, 15, -5);

    final l7 = loan(rafael, 1500, 15, 30, -50);
    pay(l7, 1725, PaymentMethod.cash, -21);

    final l8 = loan(juliana, 400, 15, 30, -45);
    pay(l8, 100, PaymentMethod.pix, -20);
    charge(l8, ChargeType.lateInterest, 30, -14);

    final l9 = loan(pedro, 1000, 10, 30, -40);
    pay(l9, 500, PaymentMethod.pix, -15);
    pay(l9, 600, PaymentMethod.transfer, -9);

    final l10 = loan(fulano, 200, 15, 15, -60);
    pay(l10, 230, PaymentMethod.pix, -46);

    final l11 = loan(maria, 3000, 15, 60, -20);
    pay(l11, 450, PaymentMethod.pix, -2);

    final l12 = loan(beatriz, 100, 10, 7, -3);
    cancelLoan(l12, 'Cadastro duplicado');

    _seeding = false;
  }
}

class _DemoLoan {
  _DemoLoan({
    required this.id,
    required this.clientId,
    required this.principal,
    required this.rate,
    required this.interest,
    required this.termDays,
    required this.start,
    required this.due,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String clientId;
  final int principal;
  final int rate;
  final int interest;
  final int termDays;
  final DateTime start;
  final DateTime due;
  final DateTime createdAt;
  final String? notes;

  LoanLifecycle status = LoanLifecycle.active;
  DateTime? paidAt;
  DateTime? cancelledAt;
  String? cancelReason;

  final charges = <LoanCharge>[];
  final payments = <Payment>[];
  final history = <HistoryEntry>[];

  int get chargesCents => charges.where((c) => c.isActive).fold(0, (s, c) => s + c.amountCents);
  int get paidCents => payments.where((p) => p.isActive).fold(0, (s, p) => s + p.amountCents);
  int get remaining => principal + interest + chargesCents - paidCents;
}
