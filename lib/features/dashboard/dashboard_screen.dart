import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/finance/loan_calculator.dart';
import '../../core/money/money.dart';
import '../../shared/models/loan.dart';
import '../../shared/models/summaries.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/aurora.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/loan_tile.dart';
import '../../theme/app_colors.dart';

final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(loansRepositoryProvider).dashboard();
});

final upcomingProvider = FutureProvider.autoDispose<List<Loan>>((ref) {
  return ref.watch(loansRepositoryProvider).upcoming(ref.watch(todayProvider));
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(dataRevisionProvider.notifier).bump();
    await ref.read(dashboardProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final upcoming = ref.watch(upcomingProvider);
    final today = ref.watch(todayProvider);
    final overdue = summary.value?.overdueCount ?? 0;

    return NivvoScaffold(
      aurora: 1,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _TopBar(hasAlert: overdue > 0),
              AsyncBody(
                value: summary,
                onRetry: () => ref.invalidate(dashboardProvider),
                loading: const SizedBox(height: 230),
                data: (s) => _Balance(summary: s),
              ),
              _Actions(overdue: overdue),
              AsyncBody(
                value: summary,
                loading: const SizedBox.shrink(),
                data: (s) => _Alerts(summary: s),
              ),
              SectionTitle(
                'Próximos vencimentos',
                trailing: TextButton(
                  onPressed: () => context.go('/loans?filter=pending'),
                  child: const Text('Ver todas'),
                ),
              ),
              AsyncBody(
                value: upcoming,
                onRetry: () => ref.invalidate(upcomingProvider),
                loading: const SizedBox(height: 120),
                data: (loans) => loans.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_available_rounded,
                        title: 'Nada vencendo',
                        message: 'Nenhuma operação em aberto com vencimento próximo.',
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < loans.length; i++) ...[
                                if (i > 0) const Divider(indent: 76, endIndent: 20),
                                LoanTile(loan: loans[i], today: today),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
              AsyncBody(
                value: summary,
                loading: const SizedBox.shrink(),
                data: (s) => _Overview(summary: s),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar, busca e alerta — como a barra superior de um app de banco.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.hasAlert});

  final bool hasAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final name = ref.watch(userProfileProvider).name;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = isDark ? const Color(0x1AFFFFFF) : const Color(0x99FFFFFF);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Material(
            color: glass,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go('/settings'),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: Text(
                    name.isEmpty ? 'N' : name[0].toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c.text),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: glass,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.go('/loans'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 20, color: c.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Buscar',
                        style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: glass,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go('/loans?filter=overdue'),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded, color: c.text, size: 22),
                    if (hasAlert)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Saldo a receber em destaque, centralizado sobre a aurora.
class _Balance extends StatelessWidget {
  const _Balance({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 8),
      child: Column(
        children: [
          Text(
            'Total a receber',
            style: TextStyle(color: c.text.withValues(alpha: 0.75), fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          BigAmount(Money.format(summary.toReceiveCents), size: 50),
          const SizedBox(height: 16),
          FrostedGlass(
            radius: 999,
            blur: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
                children: [
                  const TextSpan(text: 'Principal '),
                  TextSpan(
                    text: Money.format(summary.principalOutstandingCents),
                    style: TextStyle(color: c.text, fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: '   ·   Juros '),
                  TextSpan(
                    text: Money.format(summary.earningsOutstandingCents),
                    style: TextStyle(color: c.text, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.overdue});

  final int overdue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 28, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          RoundAction(icon: Icons.add_rounded, label: 'Nova', primary: true, onTap: () => context.push('/new-loan')),
          RoundAction(
            icon: Icons.schedule_rounded,
            label: 'Vencendo',
            onTap: () => context.go('/loans?filter=dueSoon'),
          ),
          RoundAction(
            icon: Icons.priority_high_rounded,
            label: 'Vencidas',
            badge: overdue > 0,
            onTap: () => context.go('/loans?filter=overdue'),
          ),
          RoundAction(icon: Icons.bar_chart_rounded, label: 'Relatórios', onTap: () => context.go('/reports')),
        ],
      ),
    );
  }
}

class _Alerts extends StatelessWidget {
  const _Alerts({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = <Widget>[
      if (summary.overdueCount > 0)
        _AlertCard(
          color: c.danger,
          icon: Icons.error_outline_rounded,
          title: summary.overdueCount == 1 ? '1 operação vencida' : '${summary.overdueCount} operações vencidas',
          value: Money.format(summary.overdueCents),
          onTap: () => context.go('/loans?filter=overdue'),
        ),
      if (summary.dueTodayCount > 0)
        _AlertCard(
          color: c.warning,
          icon: Icons.schedule_rounded,
          title: summary.dueTodayCount == 1
              ? '1 operação vence hoje'
              : '${summary.dueTodayCount} operações vencem hoje',
          onTap: () => context.go('/loans?filter=dueSoon'),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [for (final i in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: i)],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.color, required this.icon, required this.title, this.value, required this.onTap});

  final Color color;
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visão geral da carteira num único cartão (em vez de vários blocos soltos).
class _Overview extends StatelessWidget {
  const _Overview({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = [
      ('Recebido este mês', Money.format(summary.receivedThisMonthCents), Icons.south_west_rounded, c.success),
      ('Juros recebidos', Money.format(summary.earningsReceivedCents), Icons.trending_up_rounded, c.success),
      ('Total emprestado', Money.format(summary.totalLentCents), Icons.north_east_rounded, NivvoPalette.blueSoft),
      ('Total recebido', Money.format(summary.totalReceivedCents), Icons.account_balance_wallet_outlined, c.text),
      (
        'Operações ativas',
        '${summary.activeCount}  ·  ${summary.dueSoonCount + summary.dueTodayCount} vencendo em '
            '${LoanStatusRules.dueSoonDays} dias',
        Icons.swap_vert_rounded,
        NivvoPalette.blueSoft,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Visão geral'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const Divider(indent: 68, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: c.surfaceHigh, shape: BoxShape.circle),
                            child: Icon(rows[i].$3, size: 18, color: rows[i].$4),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              rows[i].$1,
                              style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              rows[i].$2,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
