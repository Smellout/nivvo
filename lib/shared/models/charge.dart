import '../../core/money/money.dart';
import '../../core/utils/dates.dart';

enum ChargeType {
  lateInterest('late_interest', 'Juros de atraso'),
  fine('fine', 'Multa'),
  other('other', 'Outro');

  const ChargeType(this.json, this.label);
  final String json;
  final String label;

  static ChargeType fromJson(String v) => values.firstWhere((t) => t.json == v);
}

class LoanCharge {
  const LoanCharge({
    required this.id,
    required this.loanId,
    required this.type,
    required this.amountCents,
    this.description,
    required this.chargeDate,
    required this.isActive,
    this.cancelledAt,
    this.cancelReason,
    required this.createdAt,
  });

  final String id;
  final String loanId;
  final ChargeType type;
  final int amountCents;
  final String? description;
  final DateTime chargeDate;
  final bool isActive;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime createdAt;

  factory LoanCharge.fromJson(Map<String, dynamic> json) => LoanCharge(
    id: json['id'] as String,
    loanId: json['loan_id'] as String,
    type: ChargeType.fromJson(json['type'] as String),
    amountCents: Money.fromJson(json['amount']),
    description: json['description'] as String?,
    chargeDate: Dates.parse(json['charge_date']),
    isActive: json['status'] == 'active',
    cancelledAt: json['cancelled_at'] == null ? null : DateTime.parse(json['cancelled_at'] as String),
    cancelReason: json['cancel_reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
