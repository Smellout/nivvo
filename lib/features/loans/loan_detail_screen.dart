import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/finance/loan_calculator.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../../shared/models/loan.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/aurora.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/reason_sheet.dart';
import '../../shared/widgets/status_badge.dart';
import '../../theme/app_colors.dart';
import '../charges/add_charge_sheet.dart';
import '../payments/register_payment_sheet.dart';
import 'loan_statement.dart';
import 'loans_providers.dart';

class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.loanId});

  final String loanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(loanDetailProvider(loanId));
    final today = ref.watch(todayProvider);
    final loan = detail.value?.loan;

    return NivvoScaffold(
      aurora: 0.9,
      appBar: AppBar(
        actions: [
          if (loan != null)
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'client' => context.push('/client/${loan.clientId}'),
                'cancel' => _cancelLoan(context, ref, loan),
                _ => null,
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'client', child: Text('Ver cliente')),
                if (loan.isActive && loan.paidCents == 0)
                  const PopupMenuItem(value: 'cancel', child: Text('Cancelar operação')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(dataRevisionProvider.notifier).bump();
                await ref.read(loanDetailProvider(loanId).future);
              },
              child: AsyncBody(
                value: detail,
                onRetry: () => ref.invalidate(loanDetailProvider(loanId)),
                data: (d) => _DetailBody(detail: d, today: today),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelLoan(BuildContext context, WidgetRef ref, Loan loan) async {
    final reason = await showReasonSheet(
      context,
      title: 'Cancelar operação',
      message: 'Use apenas para operações lançadas por engano. O registro continua no histórico.',
      confirmLabel: 'Cancelar operação',
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(loansRepositoryProvider).cancelLoan(loan.id, reason);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) AppFeedback.success(context, 'Operação cancelada');
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, e);
    }
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.today});

  final LoanDetail detail;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loan = detail.loan;
    final status = loan.displayStatus(today);
    final statement = LoanStatementBuilder.statement(detail);
    final timeline = LoanStatementBuilder.timeline(detail, today);

    return ListView(
      padding: const EdgeInsets.only(bottom: 48),
      children: [
        _Header(loan: loan, status: status, today: today),
        if (loan.isActive) _Actions(loan: loan, status: status) else const SizedBox(height: 8),
        const SectionTitle('Extrato da operação'),
        _StatementCard(statement: statement, loan: loan),
        const SectionTitle('Histórico'),
        _Timeline(events: timeline),
        const SectionTitle('Detalhes'),
        _InfoCard(loan: loan),
      ],
    );
  }
}

/// Cabeçalho centralizado sobre a aurora: cliente, status e saldo em destaque.
class _Header extends StatelessWidget {
  const _Header({required this.loan, required this.status, required this.today});

  final Loan loan;
  final LoanDisplayStatus status;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = loan.totalUpdatedCents;
    final progress = total == 0 ? 0.0 : (loan.paidCents / total).clamp(0.0, 1.0);
    final dueText = switch (status) {
      LoanDisplayStatus.paid => 'Quitada${loan.paidAt == null ? '' : ' em ${Dates.short(loan.paidAt!.toLocal())}'}',
      LoanDisplayStatus.cancelled => 'Cancelada',
      _ => '${Dates.relativeDue(loan.dueDate, today)} · ${Dates.short(loan.dueDate)}',
    };
    final initials = loan.clientName.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        children: [
          InitialsAvatar(initials, size: 60, color: NivvoPalette.blueSoft),
          const SizedBox(height: 12),
          Text(loan.clientName, style: context.text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusBadge(status),
              if (loan.isActive && loan.paidCents > 0 && status != LoanDisplayStatus.partial)
                const StatusBadge(LoanDisplayStatus.partial),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'Saldo atual',
            style: TextStyle(color: c.text.withValues(alpha: 0.75), fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          BigAmount(
            Money.format(loan.remainingCents),
            size: 48,
            color: status == LoanDisplayStatus.overdue ? c.danger : null,
          ),
          const SizedBox(height: 18),
          FrostedGlass(
            radius: 20,
            blur: 16,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: c.success,
                    backgroundColor: c.surfaceHigh,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pago ${Money.format(loan.paidCents)} de ${Money.format(total)}',
                        style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.event_rounded, size: 16, color: status.color(c)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dueText,
                        style: TextStyle(color: status.color(c), fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.loan, required this.status});

  final Loan loan;
  final LoanDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          RoundAction(
            icon: Icons.south_west_rounded,
            label: 'Pagamento',
            primary: true,
            onTap: () async {
              final ok = await showRegisterPayment(context, loan);
              if (ok == true && context.mounted) AppFeedback.success(context, 'Pagamento registrado');
            },
          ),
          RoundAction(
            icon: Icons.done_all_rounded,
            label: 'Quitar',
            onTap: () async {
              final ok = await showRegisterPayment(context, loan, settle: true);
              if (ok == true && context.mounted) AppFeedback.success(context, 'Operação quitada');
            },
          ),
          RoundAction(
            icon: Icons.add_rounded,
            label: 'Encargo',
            badge: status == LoanDisplayStatus.overdue,
            onTap: () async {
              final ok = await showAddCharge(context, loan);
              if (ok == true && context.mounted) AppFeedback.success(context, 'Encargo lançado');
            },
          ),
          RoundAction(
            icon: Icons.person_outline_rounded,
            label: 'Cliente',
            onTap: () => context.push('/client/${loan.clientId}'),
          ),
        ],
      ),
    );
  }
}

class _StatementCard extends ConsumerWidget {
  const _StatementCard({required this.statement, required this.loan});

  final Statement statement;
  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final line in statement.lines) _StatementRow(line: line, onTap: _actionFor(context, ref, line)),
            Container(
              color: c.surfaceHigh,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Saldo atual', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  Text(
                    Money.format(loan.remainingCents),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Toque em encargo/pagamento ativo permite cancelar/estornar (com motivo).
  VoidCallback? _actionFor(BuildContext context, WidgetRef ref, StatementLine line) {
    if (loan.lifecycle == LoanLifecycle.cancelled) return null;
    final charge = line.charge;
    final payment = line.payment;
    if (charge != null) {
      return () => _reverse(
        context,
        ref,
        title: 'Cancelar encargo',
        message:
            '${charge.type.label} de ${Money.format(charge.amountCents)} será cancelado. '
            'O lançamento continua visível no histórico.',
        confirm: 'Cancelar encargo',
        action: (reason) => ref.read(loansRepositoryProvider).cancelCharge(charge.id, reason),
        success: 'Encargo cancelado',
      );
    }
    if (payment != null) {
      return () => _reverse(
        context,
        ref,
        title: 'Estornar pagamento',
        message:
            'O pagamento de ${Money.format(payment.amountCents)} em ${Dates.short(payment.paymentDate)} '
            'deixará de contar no saldo. O registro continua no histórico.',
        confirm: 'Estornar pagamento',
        action: (reason) => ref.read(loansRepositoryProvider).cancelPayment(payment.id, reason),
        success: 'Pagamento estornado',
      );
    }
    return null;
  }

  Future<void> _reverse(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required String confirm,
    required Future<void> Function(String reason) action,
    required String success,
  }) async {
    final reason = await showReasonSheet(context, title: title, message: message, confirmLabel: confirm);
    if (reason == null || !context.mounted) return;
    try {
      await action(reason);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) AppFeedback.success(context, success);
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, e);
    }
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({required this.line, this.onTap});

  final StatementLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color) = switch (line.kind) {
      StatementKind.principal => (Icons.north_east_rounded, NivvoPalette.blueSoft),
      StatementKind.interest => (Icons.percent_rounded, c.brand),
      StatementKind.charge => (Icons.add_circle_outline_rounded, c.warning),
      StatementKind.payment => (Icons.south_west_rounded, c.success),
    };
    final amount = switch (line.kind) {
      StatementKind.principal => Money.format(line.cents),
      _ => Money.formatSigned(line.cents),
    };
    final sub = [
      if (line.subtitle != null && line.subtitle!.isNotEmpty) line.subtitle!,
      if (line.date != null && line.kind != StatementKind.principal && line.kind != StatementKind.interest)
        Dates.short(line.date!),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: line.kind == StatementKind.payment ? c.success : c.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.more_vert_rounded, size: 18, color: c.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<TimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Column(
            children: [
              for (var i = 0; i < events.length; i++)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 20,
                        child: Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(color: _toneColor(c, events[i].tone), shape: BoxShape.circle),
                            ),
                            if (i < events.length - 1) Expanded(child: Container(width: 2, color: c.border)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Dates.short(events[i].date), style: TextStyle(color: c.textSecondary, fontSize: 12)),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(events[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  if (events[i].amountText != null)
                                    Text(
                                      events[i].amountText!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: events[i].struck
                                            ? c.textSecondary
                                            : _toneColor(c, events[i].tone, text: true),
                                        decoration: events[i].struck ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                ],
                              ),
                              if (events[i].detail != null && events[i].detail!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    events[i].detail!,
                                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _toneColor(NivvoColors c, TimelineTone tone, {bool text = false}) => switch (tone) {
    TimelineTone.positive => c.success,
    TimelineTone.negative => c.textSecondary,
    TimelineTone.warning => c.warning,
    TimelineTone.danger => c.danger,
    TimelineTone.neutral => text ? c.text : c.brand,
  };
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.loan});

  final Loan loan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KeyValueRow('Data da operação', Dates.short(loan.startDate)),
              KeyValueRow('Prazo', '${loan.termDays} ${loan.termDays == 1 ? 'dia' : 'dias'}'),
              KeyValueRow('Vencimento', Dates.short(loan.dueDate)),
              KeyValueRow('Taxa', Rate.format(loan.rateHundredths)),
              KeyValueRow('Total inicial', Money.format(loan.totalInitialCents)),
              if (loan.chargesCents > 0) KeyValueRow('Encargos', Money.format(loan.chargesCents)),
              KeyValueRow('Juros e encargos recebidos', Money.format(loan.earningsReceivedCents)),
              if (loan.notes != null) ...[
                const SizedBox(height: 8),
                Text('Observação', style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                const SizedBox(height: 2),
                Text(loan.notes!),
                const SizedBox(height: 6),
              ],
              if (loan.cancelReason != null) KeyValueRow('Motivo do cancelamento', loan.cancelReason!),
            ],
          ),
        ),
      ),
    );
  }
}
