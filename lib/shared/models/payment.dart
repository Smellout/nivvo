import 'package:material_ui/material_ui.dart';

import '../../core/money/money.dart';
import '../../core/utils/dates.dart';

enum PaymentMethod {
  pix('pix', 'PIX', Icons.bolt_rounded),
  cash('cash', 'Dinheiro', Icons.payments_outlined),
  transfer('transfer', 'Transferência', Icons.account_balance_outlined),
  other('other', 'Outro', Icons.more_horiz_rounded);

  const PaymentMethod(this.json, this.label, this.icon);
  final String json;
  final String label;
  final IconData icon;

  static PaymentMethod fromJson(String v) => values.firstWhere((m) => m.json == v);
}

class Payment {
  const Payment({
    required this.id,
    required this.loanId,
    required this.amountCents,
    required this.method,
    required this.paymentDate,
    this.notes,
    required this.isActive,
    this.cancelledAt,
    this.cancelReason,
    required this.createdAt,
  });

  final String id;
  final String loanId;
  final int amountCents;
  final PaymentMethod method;
  final DateTime paymentDate;
  final String? notes;
  final bool isActive;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime createdAt;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    loanId: json['loan_id'] as String,
    amountCents: Money.fromJson(json['amount']),
    method: PaymentMethod.fromJson(json['payment_method'] as String),
    paymentDate: Dates.parse(json['payment_date']),
    notes: json['notes'] as String?,
    isActive: json['status'] == 'active',
    cancelledAt: json['cancelled_at'] == null ? null : DateTime.parse(json['cancelled_at'] as String),
    cancelReason: json['cancel_reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
