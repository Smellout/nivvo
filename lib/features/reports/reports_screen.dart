import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../../shared/models/summaries.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/aurora.dart';
import '../../shared/widgets/common.dart';
import '../../theme/app_colors.dart';

enum ReportPeriod {
  today('Hoje'),
  last7('7 dias'),
  thisMonth('Este mês'),
  lastMonth('Mês anterior'),
  custom('Personalizado');

  const ReportPeriod(this.label);
  final String label;

  (DateTime, DateTime) range(DateTime today) => switch (this) {
    ReportPeriod.today => (today, today),
    ReportPeriod.last7 => (Dates.addDays(today, -6), today),
    ReportPeriod.thisMonth => (DateTime.utc(today.year, today.month, 1), today),
    ReportPeriod.lastMonth => (DateTime.utc(today.year, today.month - 1, 1), DateTime.utc(today.year, today.month, 0)),
    ReportPeriod.custom => (today, today),
  };
}

typedef ReportRange = ({DateTime from, DateTime to});

final reportProvider = FutureProvider.autoDispose.family<ReportSummary, ReportRange>((ref, range) {
  ref.watch(dataRevisionProvider);
  return ref.watch(reportsRepositoryProvider).summary(range.from, range.to);
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.thisMonth;
  ReportRange? _custom;

  ReportRange _range(DateTime today) {
    if (_period == ReportPeriod.custom && _custom != null) return _custom!;
    final (from, to) = _period.range(today);
    return (from: from, to: to);
  }

  Future<void> _pickCustom() async {
    final today = Dates.today();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.utc(today.year - 10),
      lastDate: today,
      initialDateRange: _custom == null ? null : DateTimeRange(start: _custom!.from, end: _custom!.to),
      helpText: 'Período do relatório',
    );
    if (picked == null) return;
    setState(() {
      _period = ReportPeriod.custom;
      _custom = (from: Dates.dateOnly(picked.start), to: Dates.dateOnly(picked.end));
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final range = _range(today);
    final report = ref.watch(reportProvider(range));
    final c = context.colors;

    return NivvoScaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(dataRevisionProvider.notifier).bump();
          await ref.read(reportProvider(_range(Dates.today())).future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final p in ReportPeriod.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.label),
                        selected: _period == p,
                        labelStyle: TextStyle(
                          color: _period == p ? Colors.white : c.text,
                          fontWeight: _period == p ? FontWeight.w600 : FontWeight.w500,
                        ),
                        onSelected: (_) => p == ReportPeriod.custom ? _pickCustom() : setState(() => _period = p),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                range.from == range.to
                    ? Dates.short(range.from)
                    : '${Dates.short(range.from)} — ${Dates.short(range.to)}',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            ),
            AsyncBody(
              value: report,
              onRetry: () => ref.invalidate(reportProvider(range)),
              loading: const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              ),
              data: (r) => _ReportBody(report: r),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final ReportSummary report;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Recebimentos no período'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Money.format(r.totalReceivedCents),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8),
                  ),
                  Text(
                    '${r.paymentsCount} ${r.paymentsCount == 1 ? 'pagamento' : 'pagamentos'}',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(height: 140, child: _BarChart(points: _buckets(r))),
                ],
              ),
            ),
          ),
        ),
        const SectionTitle('Movimento do período'),
        _Grid(
          items: [
            ('Total emprestado', Money.format(r.totalLentCents), NivvoPalette.blueSoft),
            ('Total de juros', Money.format(r.totalInterestCents), c.brand),
            ('Total de encargos', Money.format(r.totalChargesCents), c.warning),
            ('Total recebido', Money.format(r.totalReceivedCents), c.success),
            ('Operações criadas', '${r.loansCount}', c.text),
            ('Pagamentos', '${r.paymentsCount}', c.text),
          ],
        ),
        const SectionTitle('Carteira hoje'),
        _Grid(
          items: [
            ('Total pendente', Money.format(r.totalPendingCents), c.text),
            ('Total vencido', Money.format(r.totalOverdueCents), c.danger),
          ],
        ),
      ],
    );
  }

  /// Dias do período (ou meses, se o período for longo) com o total recebido.
  static List<({String label, int cents})> _buckets(ReportSummary r) {
    final days = Dates.daysBetween(r.from, r.to) + 1;
    final byDay = {for (final p in r.series) Dates.toJson(p.date): p.cents};
    if (days <= 62) {
      return [
        for (var i = 0; i < days; i++)
          (
            label: Dates.dayMonthShort(Dates.addDays(r.from, i)),
            cents: byDay[Dates.toJson(Dates.addDays(r.from, i))] ?? 0,
          ),
      ];
    }
    final months = <String, int>{};
    for (var d = DateTime.utc(r.from.year, r.from.month); !d.isAfter(r.to); d = DateTime.utc(d.year, d.month + 1)) {
      months['${d.month.toString().padLeft(2, '0')}/${d.year % 100}'] = 0;
    }
    for (final p in r.series) {
      final key = '${p.date.month.toString().padLeft(2, '0')}/${p.date.year % 100}';
      months[key] = (months[key] ?? 0) + p.cents;
    }
    return [for (final e in months.entries) (label: e.key, cents: e.value)];
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items});

  final List<(String, String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2,
        children: [
          for (final (label, value, color) in items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
                      ),
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

class _BarChart extends StatelessWidget {
  const _BarChart({required this.points});

  final List<({String label, int cents})> points;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (points.every((p) => p.cents == 0)) {
      return Center(
        child: Text('Sem recebimentos no período', style: TextStyle(color: c.textSecondary)),
      );
    }
    return Semantics(
      label: 'Gráfico de recebimentos por dia',
      child: CustomPaint(
        size: Size.infinite,
        painter: _BarPainter(points: points, bar: c.brand, empty: c.surfaceHigh, labelColor: c.textSecondary),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.points, required this.bar, required this.empty, required this.labelColor});

  final List<({String label, int cents})> points;
  final Color bar;
  final Color empty;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 18.0;
    final chartHeight = size.height - labelHeight;
    final maxCents = points.map((p) => p.cents).fold<int>(0, (a, b) => a > b ? a : b);
    final slot = size.width / points.length;
    final barWidth = (slot * 0.62).clamp(2.0, 28.0);

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = slot * i + (slot - barWidth) / 2;
      final h = maxCents == 0 ? 0.0 : (p.cents / maxCents) * (chartHeight - 4);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, chartHeight - (h < 3 ? 3 : h), barWidth, h < 3 ? 3 : h),
        topLeft: Radius.circular(barWidth / 3),
        topRight: Radius.circular(barWidth / 3),
      );
      canvas.drawRRect(rect, Paint()..color = p.cents == 0 ? empty : bar);
    }

    // Rótulos só no início, meio e fim para não poluir.
    final idx = {0, points.length ~/ 2, points.length - 1};
    for (final i in idx) {
      final tp = TextPainter(
        text: TextSpan(
          text: points[i].label,
          style: TextStyle(color: labelColor, fontSize: 10.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = slot * i + slot / 2 - tp.width / 2;
      tp.paint(canvas, Offset(cx.clamp(0, size.width - tp.width), chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.points != points || old.bar != bar;
}
