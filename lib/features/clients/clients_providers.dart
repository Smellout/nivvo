import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/client.dart';
import '../../shared/repositories/clients_repository.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../loans/loans_providers.dart';

class ClientsPager extends AsyncNotifier<PagedState<ClientSummary>> {
  ClientsPager(this.search);

  final String search;

  @override
  Future<PagedState<ClientSummary>> build() async {
    ref.watch(dataRevisionProvider);
    final items = await ref.read(clientsRepositoryProvider).list(query: search);
    return PagedState(items: items, hasMore: items.length == ClientsRepository.pageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore || state.isLoading) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final more = await ref.read(clientsRepositoryProvider).list(query: search, offset: current.items.length);
      state = AsyncData(
        PagedState(items: [...current.items, ...more], hasMore: more.length == ClientsRepository.pageSize),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final clientsPagerProvider = AsyncNotifierProvider.autoDispose.family<ClientsPager, PagedState<ClientSummary>, String>(
  ClientsPager.new,
);

final clientDetailProvider = FutureProvider.autoDispose.family<ClientSummary, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(clientsRepositoryProvider).get(id);
});

final recentClientsProvider = FutureProvider.autoDispose<List<Client>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(clientsRepositoryProvider).recent();
});

/// Busca para o seletor de clientes (sem paginação: mostra os 30 primeiros).
final clientSearchProvider = FutureProvider.autoDispose.family<List<ClientSummary>, String>((ref, q) {
  ref.watch(dataRevisionProvider);
  return ref.watch(clientsRepositoryProvider).list(query: q);
});
