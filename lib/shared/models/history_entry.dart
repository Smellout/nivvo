import '../../core/money/money.dart';
import '../../core/utils/dates.dart';

enum HistoryAction {
  loanCreated('loan_created'),
  chargeAdded('charge_added'),
  chargeCancelled('charge_cancelled'),
  paymentRegistered('payment_registered'),
  paymentCancelled('payment_cancelled'),
  loanPaid('loan_paid'),
  loanReopened('loan_reopened'),
  loanCancelled('loan_cancelled');

  const HistoryAction(this.json);
  final String json;

  static HistoryAction fromJson(String v) => values.firstWhere((a) => a.json == v);
}

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.action,
    this.amountCents,
    required this.eventDate,
    this.description,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final HistoryAction action;
  final int? amountCents;
  final DateTime eventDate;
  final String? description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    action: HistoryAction.fromJson(json['action'] as String),
    amountCents: json['amount'] == null ? null : Money.fromJson(json['amount']),
    eventDate: Dates.parse(json['event_date']),
    description: json['description'] as String?,
    metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
