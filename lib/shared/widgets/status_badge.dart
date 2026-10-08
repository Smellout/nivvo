import 'package:material_ui/material_ui.dart';

import '../../core/finance/loan_calculator.dart';
import '../../theme/app_colors.dart';

extension LoanDisplayStatusColor on LoanDisplayStatus {
  Color color(NivvoColors c) => switch (this) {
    LoanDisplayStatus.paid => c.success,
    LoanDisplayStatus.dueSoon || LoanDisplayStatus.dueToday => c.warning,
    LoanDisplayStatus.overdue => c.danger,
    LoanDisplayStatus.cancelled => c.neutral,
    LoanDisplayStatus.partial => NivvoPalette.blueSoft,
    LoanDisplayStatus.pending => c.textSecondary,
  };
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.compact = false});

  final LoanDisplayStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = status.color(context.colors);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
