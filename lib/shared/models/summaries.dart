import '../../core/money/money.dart';
import '../../core/utils/dates.dart';

/// Resultado de `dashboard_summary()`.
class DashboardSummary {
  const DashboardSummary({
    required this.toReceiveCents,
    required this.principalOutstandingCents,
    required this.activeCount,
    required this.overdueCount,
    required this.overdueCents,
    required this.dueTodayCount,
    required this.dueSoonCount,
    required this.totalLentCents,
    required this.totalReceivedCents,
    required this.earningsReceivedCents,
    required this.receivedThisMonthCents,
  });

  final int toReceiveCents;
  final int principalOutstandingCents;
  final int activeCount;
  final int overdueCount;
  final int overdueCents;
  final int dueTodayCount;
  final int dueSoonCount;
  final int totalLentCents;
  final int totalReceivedCents;
  final int earningsReceivedCents;
  final int receivedThisMonthCents;

  /// Juros + encargos ainda a receber.
  int get earningsOutstandingCents => toReceiveCents - principalOutstandingCents;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
    toReceiveCents: Money.fromJson(json['to_receive']),
    principalOutstandingCents: Money.fromJson(json['principal_outstanding']),
    activeCount: (json['active_count'] as num).toInt(),
    overdueCount: (json['overdue_count'] as num).toInt(),
    overdueCents: Money.fromJson(json['overdue_amount']),
    dueTodayCount: (json['due_today_count'] as num).toInt(),
    dueSoonCount: (json['due_soon_count'] as num).toInt(),
    totalLentCents: Money.fromJson(json['total_lent']),
    totalReceivedCents: Money.fromJson(json['total_received']),
    earningsReceivedCents: Money.fromJson(json['earnings_received']),
    receivedThisMonthCents: Money.fromJson(json['received_this_month']),
  );
}

class DailyAmount {
  const DailyAmount(this.date, this.cents);
  final DateTime date;
  final int cents;
}

/// Resultado de `report_summary(from, to)`.
class ReportSummary {
  const ReportSummary({
    required this.from,
    required this.to,
    required this.totalLentCents,
    required this.totalInterestCents,
    required this.loansCount,
    required this.totalChargesCents,
    required this.totalReceivedCents,
    required this.paymentsCount,
    required this.totalPendingCents,
    required this.totalOverdueCents,
    required this.series,
  });

  final DateTime from;
  final DateTime to;
  final int totalLentCents;
  final int totalInterestCents;
  final int loansCount;
  final int totalChargesCents;
  final int totalReceivedCents;
  final int paymentsCount;
  final int totalPendingCents;
  final int totalOverdueCents;
  final List<DailyAmount> series;

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
    from: Dates.parse(json['from']),
    to: Dates.parse(json['to']),
    totalLentCents: Money.fromJson(json['total_lent']),
    totalInterestCents: Money.fromJson(json['total_interest']),
    loansCount: (json['loans_count'] as num).toInt(),
    totalChargesCents: Money.fromJson(json['total_charges']),
    totalReceivedCents: Money.fromJson(json['total_received']),
    paymentsCount: (json['payments_count'] as num).toInt(),
    totalPendingCents: Money.fromJson(json['total_pending']),
    totalOverdueCents: Money.fromJson(json['total_overdue']),
    series: [
      for (final row in (json['series'] as List).cast<Map<String, dynamic>>())
        DailyAmount(Dates.parse(row['date']), Money.fromJson(row['received'])),
    ],
  );
}
