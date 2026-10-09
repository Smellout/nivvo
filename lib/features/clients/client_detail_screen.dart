import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money/money.dart';
import '../../core/utils/validators.dart';
import '../../shared/models/client.dart';
import '../../shared/repositories/loans_repository.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/aurora.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/loan_tile.dart';
import '../../theme/app_colors.dart';
import '../loans/loans_providers.dart';
import 'client_sheets.dart';
import 'clients_providers.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(clientDetailProvider(clientId));
    final LoansQuery query = (filter: LoanFilter.all, search: '', clientId: clientId);
    final loans = ref.watch(loansPagerProvider(query));
    final today = ref.watch(todayProvider);
    final client = summary.value?.client;

    return NivvoScaffold(
      appBar: AppBar(
        title: Text(client?.name ?? 'Cliente'),
        actions: [
          if (client != null)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showClientForm(context, client: client),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-loan-client',
        onPressed: () => context.push('/new-loan?clientId=$clientId'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova operação'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(dataRevisionProvider.notifier).bump();
          await ref.read(clientDetailProvider(clientId).future);
        },
        child: AsyncBody(
          value: summary,
          onRetry: () => ref.invalidate(clientDetailProvider(clientId)),
          data: (s) => ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _ClientHeader(summary: s),
              const SectionTitle('Operações'),
              AsyncBody(
                value: loans,
                onRetry: () => ref.invalidate(loansPagerProvider(query)),
                loading: const SizedBox(height: 80),
                data: (page) => page.items.isEmpty
                    ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'Nenhuma operação')
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < page.items.length; i++) ...[
                                if (i > 0) const Divider(indent: 72),
                                LoanTile(loan: page.items[i], today: today, showClient: false),
                              ],
                              if (page.hasMore)
                                TextButton(
                                  onPressed: () => ref.read(loansPagerProvider(query).notifier).loadMore(),
                                  child: const Text('Carregar mais'),
                                ),
                            ],
                          ),
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

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({required this.summary});

  final ClientSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final client = summary.client;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(client.initials, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.name, style: context.text.titleLarge),
                        const SizedBox(height: 2),
                        Text(clientSince(client), style: TextStyle(color: c.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              if (client.phone != null || client.cpf != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    if (client.phone != null) _Info(icon: Icons.phone_outlined, text: Formatters.phone(client.phone)),
                    if (client.cpf != null) _Info(icon: Icons.badge_outlined, text: Formatters.cpf(client.cpf)),
                  ],
                ),
              ],
              if (client.notes != null) ...[
                const SizedBox(height: 10),
                Text(client.notes!, style: TextStyle(color: c.textSecondary)),
              ],
              const SizedBox(height: 18),
              Text('Saldo pendente', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              Text(
                Money.format(summary.balanceCents),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: summary.overdueCount > 0 ? c.danger : c.text,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Stat('Emprestado', Money.format(summary.totalLentCents))),
                  Expanded(child: _Stat('Recebido', Money.format(summary.totalReceivedCents))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _Stat('Operações', '${summary.loansCount}')),
                  Expanded(
                    child: _Stat(
                      'Vencidas',
                      '${summary.overdueCount}',
                      color: summary.overdueCount > 0 ? c.danger : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.colors.textSecondary),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: color ?? c.text),
        ),
      ],
    );
  }
}
