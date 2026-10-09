import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money/money.dart';
import '../../core/utils/validators.dart';
import '../../shared/models/client.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/aurora.dart';
import '../../shared/widgets/common.dart';
import '../../theme/app_colors.dart';
import 'client_sheets.dart';
import 'clients_providers.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _search = '';
  Timer? _debounce;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) ref.read(clientsPagerProvider(_search).notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(clientsPagerProvider(_search));

    return NivvoScaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            tooltip: 'Novo cliente',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () async {
              final created = await showClientForm(context);
              if (created != null && context.mounted) context.push('/client/${created.id}');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nome, telefone ou CPF',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (t) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) setState(() => _search = t.trim());
                });
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(dataRevisionProvider.notifier).bump();
                await ref.read(clientsPagerProvider(_search).future);
              },
              child: AsyncBody(
                value: page,
                onRetry: () => ref.invalidate(clientsPagerProvider(_search)),
                data: (state) {
                  if (state.items.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: _search.isEmpty ? 'Nenhum cliente ainda' : 'Nenhum cliente encontrado',
                          message: _search.isEmpty ? 'Os clientes aparecem aqui ao criar a primeira operação.' : null,
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.only(top: 4, bottom: 96),
                    itemCount: state.items.length + (state.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(indent: 76),
                    itemBuilder: (context, i) {
                      if (i >= state.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                        );
                      }
                      return _ClientTile(summary: state.items[i]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.summary});

  final ClientSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final client = summary.client;
    return InkWell(
      onTap: () => context.push('/client/${client.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(client.initials, color: summary.overdueCount > 0 ? c.danger : null),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      summary.loansCount == 0
                          ? 'Sem operações'
                          : '${summary.loansCount} ${summary.loansCount == 1 ? 'operação' : 'operações'}',
                      if (client.phone != null) Formatters.phone(client.phone),
                    ].join(' · '),
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Money.format(summary.balanceCents),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: summary.balanceCents > 0 ? c.text : c.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  summary.overdueCount > 0
                      ? '${summary.overdueCount} ${summary.overdueCount == 1 ? 'vencida' : 'vencidas'}'
                      : (summary.balanceCents > 0 ? 'em aberto' : 'sem saldo'),
                  style: TextStyle(
                    fontSize: 12,
                    color: summary.overdueCount > 0 ? c.danger : c.textSecondary,
                    fontWeight: summary.overdueCount > 0 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
