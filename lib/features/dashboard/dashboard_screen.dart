import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/finance/loan_calculator.dart';
import '../../core/money/money.dart';
import '../../shared/models/loan.dart';
import '../../shared/models/summaries.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _Greeting()),
            SliverToBoxAdapter(
              child: AsyncBody(
                value: summary,
                onRetry: () => ref.invalidate(dashboardProvider),
                loading: const _HeroSkeleton(),
                data: (s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BalanceHero(summary: s),
                    _Alerts(summary: s),
                    const _NewLoanButton(),
                    _Metrics(summary: s),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionTitle(
                'Próximos vencimentos',
                trailing: TextButton(
                  onPressed: () => context.go('/loans?filter=pending'),
                  child: const Text('Ver todas'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AsyncBody(
                value: upcoming,
                onRetry: () => ref.invalidate(upcomingProvider),
                loading: const SizedBox(height: 120),
                data: (loans) => loans.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: EmptyState(
                          icon: Icons.event_available_rounded,
                          title: 'Nada vencendo',
                          message: 'Nenhuma operação em aberto com vencimento próximo.',
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < loans.length; i++) ...[
                                if (i > 0) const Divider(indent: 72),
                                LoanTile(loan: loans[i], today: today),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateProvider);
    final user = ref.watch(supabaseProvider).auth.currentUser;
    final name = (user?.userMetadata?['name'] as String?)?.trim().split(' ').first ?? '';
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bom dia' : (hour < 18 ? 'Boa tarde' : 'Boa noite');
    final date = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.isEmpty ? greeting : '$greeting, $name', style: context.text.headlineSmall),
          const SizedBox(height: 2),
          Text(
            date[0].toUpperCase() + date.substring(1),
            style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1B2A55), Color(0xFF14203D), Color(0xFF0F2A2A)]
              : const [Color(0xFF3F67F0), Color(0xFF4F7CFF), Color(0xFF2CB98C)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.06 : 0)),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total a receber', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Money.format(summary.toReceiveCents),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.4,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeroPart(label: 'Principal', cents: summary.principalOutstandingCents),
                ),
                Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(width: 16),
                Expanded(
                  child: _HeroPart(label: 'Juros e encargos', cents: summary.earningsOutstandingCents),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.south_west_rounded, size: 16, color: c.success),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Recebido este mês  ${Money.format(summary.receivedThisMonthCents)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
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
}

class _HeroPart extends StatelessWidget {
  const _HeroPart({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12.5)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Money.format(cents),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(26)),
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
    if (items.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewLoanButton extends StatelessWidget {
  const _NewLoanButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: FilledButton.icon(
        onPressed: () => context.push('/new-loan'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova operação'),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tiles = [
      _Metric(
        'Operações ativas',
        '${summary.activeCount}',
        Icons.swap_vert_rounded,
        c.brand,
        () => context.go('/loans?filter=pending'),
      ),
      _Metric(
        'Vencendo (${LoanStatusRules.dueSoonDays} dias)',
        '${summary.dueSoonCount + summary.dueTodayCount}',
        Icons.schedule_rounded,
        c.warning,
        () => context.go('/loans?filter=dueSoon'),
      ),
      _Metric(
        'Vencidas',
        '${summary.overdueCount}',
        Icons.error_outline_rounded,
        c.danger,
        () => context.go('/loans?filter=overdue'),
      ),
      _Metric(
        'Total emprestado',
        Money.format(summary.totalLentCents),
        Icons.north_east_rounded,
        NivvoPalette.blueSoft,
        null,
      ),
      _Metric('Total recebido', Money.format(summary.totalReceivedCents), Icons.south_west_rounded, c.success, null),
      _Metric(
        'Juros recebidos',
        Money.format(summary.earningsReceivedCents),
        Icons.trending_up_rounded,
        c.success,
        null,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.75,
        children: [for (final t in tiles) _MetricCard(metric: t)],
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color, this.onTap);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: metric.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(metric.icon, size: 18, color: metric.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  metric.value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    letterSpacing: -0.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
