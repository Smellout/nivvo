import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/finance/loan_calculator.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../../theme/app_colors.dart';
import '../models/loan.dart';
import 'common.dart';
import 'status_badge.dart';

/// Item de lista de operação: cliente, saldo, vencimento e status.
class LoanTile extends StatelessWidget {
  const LoanTile({super.key, required this.loan, required this.today, this.showClient = true});

  final Loan loan;
  final DateTime today;
  final bool showClient;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = loan.displayStatus(today);
    final subtitle = switch (status) {
      LoanDisplayStatus.paid => 'Quitada${loan.paidAt == null ? '' : ' em ${Dates.short(loan.paidAt!.toLocal())}'}',
      LoanDisplayStatus.cancelled => 'Cancelada',
      _ => Dates.relativeDue(loan.dueDate, today),
    };
    final amount = status.isOpen ? loan.remainingCents : loan.totalUpdatedCents;
    final initials = loan.clientName.trim().isEmpty
        ? '?'
        : loan.clientName.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();

    return InkWell(
      onTap: () => context.push('/loan/${loan.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(
              initials,
              color: switch (status) {
                LoanDisplayStatus.overdue => c.danger,
                _ when status.isOpen => NivvoPalette.blueSoft,
                _ => c.neutral,
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showClient ? loan.clientName : 'Operação de ${Dates.short(loan.startDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: status == LoanDisplayStatus.overdue ? c.danger : c.textSecondary,
                      fontWeight: status == LoanDisplayStatus.overdue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Money.format(amount),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: status.isOpen ? c.text : c.textSecondary,
                    decoration: status == LoanDisplayStatus.cancelled ? TextDecoration.lineThrough : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge(status, compact: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
