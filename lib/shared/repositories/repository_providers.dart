import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/core_providers.dart';
import 'auth_repository.dart';
import 'clients_repository.dart';
import 'loans_repository.dart';
import 'reports_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider), ref.watch(localCacheProvider)),
);

final clientsRepositoryProvider = Provider<ClientsRepository>(
  (ref) => ClientsRepository(
    client: ref.watch(supabaseProvider),
    cache: ref.watch(localCacheProvider),
    onOffline: ref.read(offlineProvider.notifier).set,
  ),
);

final loansRepositoryProvider = Provider<LoansRepository>(
  (ref) => LoansRepository(
    client: ref.watch(supabaseProvider),
    cache: ref.watch(localCacheProvider),
    onOffline: ref.read(offlineProvider.notifier).set,
  ),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(
    client: ref.watch(supabaseProvider),
    cache: ref.watch(localCacheProvider),
    onOffline: ref.read(offlineProvider.notifier).set,
  ),
);
