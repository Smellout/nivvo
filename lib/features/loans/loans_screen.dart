import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/repositories/loans_repository.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/aurora.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/loan_tile.dart';
import '../../theme/app_colors.dart';
import 'loans_providers.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key, this.filterName});

  /// Filtro vindo da URL (`/loans?filter=overdue`), usado por atalhos do Início.
  final String? filterName;

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  late LoanFilter _filter = LoanFilter.fromName(widget.filterName);
  String _search = '';
  Timer? _debounce;
  final _scroll = ScrollController();

  LoansQuery get _query => (filter: _filter, search: _search, clientId: null);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(LoansScreen old) {
    super.didUpdateWidget(old);
    if (widget.filterName != old.filterName && widget.filterName != null) {
      setState(() => _filter = LoanFilter.fromName(widget.filterName));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 400) ref.read(loansPagerProvider(_query).notifier).loadMore();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _search = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(loansPagerProvider(_query));
    final today = ref.watch(todayProvider);
    final c = context.colors;

    return NivvoScaffold(
      appBar: AppBar(title: const Text('Operações')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Buscar por nome, telefone ou CPF',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in LoanFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      labelStyle: TextStyle(
                        color: _filter == f ? Colors.white : c.text,
                        fontWeight: _filter == f ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(dataRevisionProvider.notifier).bump();
                await ref.read(loansPagerProvider(_query).future);
              },
              child: AsyncBody(
                value: page,
                onRetry: () => ref.invalidate(loansPagerProvider(_query)),
                data: (state) {
                  if (state.items.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _search.isEmpty ? 'Nenhuma operação aqui' : 'Nada encontrado',
                          message: _search.isEmpty
                              ? 'Toque em + para registrar uma nova operação.'
                              : 'Tente outro nome, telefone ou CPF.',
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
                      return LoanTile(loan: state.items[i], today: today);
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
