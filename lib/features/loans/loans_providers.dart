import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/loan.dart';
import '../../shared/repositories/loans_repository.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';

typedef LoansQuery = ({LoanFilter filter, String search, String? clientId});

class PagedState<T> {
  const PagedState({required this.items, required this.hasMore, this.loadingMore = false});

  final List<T> items;
  final bool hasMore;
  final bool loadingMore;

  PagedState<T> copyWith({List<T>? items, bool? hasMore, bool? loadingMore}) => PagedState(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Lista paginada de operações (carrega 25 por vez conforme a rolagem).
class LoansPager extends AsyncNotifier<PagedState<Loan>> {
  LoansPager(this.query);

  final LoansQuery query;

  Future<List<Loan>> _fetch(int offset) => ref
      .read(loansRepositoryProvider)
      .list(
        filter: query.filter,
        today: ref.read(todayProvider),
        query: query.search,
        clientId: query.clientId,
        offset: offset,
      );

  @override
  Future<PagedState<Loan>> build() async {
    ref.watch(dataRevisionProvider);
    final items = await _fetch(0);
    return PagedState(items: items, hasMore: items.length == LoansRepository.pageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore || state.isLoading) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final more = await _fetch(current.items.length);
      state = AsyncData(
        PagedState(items: [...current.items, ...more], hasMore: more.length == LoansRepository.pageSize),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final loansPagerProvider = AsyncNotifierProvider.autoDispose.family<LoansPager, PagedState<Loan>, LoansQuery>(
  LoansPager.new,
);

final loanDetailProvider = FutureProvider.autoDispose.family<LoanDetail, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(loansRepositoryProvider).detail(id);
});
