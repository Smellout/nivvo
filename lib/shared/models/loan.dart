import '../../core/finance/loan_calculator.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import 'charge.dart';
import 'history_entry.dart';
import 'payment.dart';

/// Operação de empréstimo (view `loan_overview`). Valores em centavos.
class Loan {
  const Loan({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientPhone,
    required this.principalCents,
    required this.rateHundredths,
    required this.interestCents,
    required this.chargesCents,
    required this.paidCents,
    required this.remainingCents,
    required this.earningsReceivedCents,
    required this.termDays,
    required this.startDate,
    required this.dueDate,
    required this.lifecycle,
    this.notes,
    this.paidAt,
    this.cancelledAt,
    this.cancelReason,
    required this.createdAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String? clientPhone;
  final int principalCents;
  final int rateHundredths;
  final int interestCents;
  final int chargesCents;
  final int paidCents;
  final int remainingCents;
  final int earningsReceivedCents;
  final int termDays;
  final DateTime startDate;
  final DateTime dueDate;
  final LoanLifecycle lifecycle;
  final String? notes;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime createdAt;

  int get totalInitialCents => principalCents + interestCents;

  /// Total atualizado = principal + juros + encargos.
  int get totalUpdatedCents => totalInitialCents + chargesCents;

  bool get isActive => lifecycle == LoanLifecycle.active;

  LoanDisplayStatus displayStatus(DateTime today) => LoanStatusRules.resolve(
    lifecycle: lifecycle,
    remainingCents: remainingCents,
    paidCents: paidCents,
    dueDate: dueDate,
    today: today,
  );

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
    id: json['id'] as String,
    clientId: json['client_id'] as String,
    clientName: (json['client_name'] as String?) ?? '',
    clientPhone: json['client_phone'] as String?,
    principalCents: Money.fromJson(json['principal_amount']),
    rateHundredths: Rate.fromJson(json['interest_rate']),
    interestCents: Money.fromJson(json['interest_amount']),
    chargesCents: Money.fromJson(json['charges_amount']),
    paidCents: Money.fromJson(json['paid_amount']),
    remainingCents: Money.fromJson(json['remaining_amount']),
    earningsReceivedCents: Money.fromJson(json['earnings_received']),
    termDays: (json['term_days'] as num).toInt(),
    startDate: Dates.parse(json['start_date']),
    dueDate: Dates.parse(json['due_date']),
    lifecycle: LoanLifecycle.fromJson(json['status'] as String),
    notes: json['notes'] as String?,
    paidAt: _ts(json['paid_at']),
    cancelledAt: _ts(json['cancelled_at']),
    cancelReason: json['cancel_reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  static DateTime? _ts(Object? v) => v == null ? null : DateTime.parse(v as String);
}

/// Operação + lançamentos + histórico, para a tela de detalhes.
class LoanDetail {
  const LoanDetail({required this.loan, required this.charges, required this.payments, required this.history});

  final Loan loan;
  final List<LoanCharge> charges;
  final List<Payment> payments;
  final List<HistoryEntry> history;

  List<LoanCharge> get activeCharges => charges.where((c) => c.isActive).toList();
  List<Payment> get activePayments => payments.where((p) => p.isActive).toList();
}
