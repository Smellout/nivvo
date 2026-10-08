import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cache/local_cache.dart';
import '../../core/utils/dates.dart';

/// Inicializado em `main()` e injetado via override.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider deve ser sobrescrito em main()'),
);

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final localCacheProvider = Provider<LocalCache>((ref) => LocalCache(ref.watch(sharedPreferencesProvider)));

final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(supabaseProvider).auth.onAuthStateChange);

/// Id do usuário logado (null quando deslogado).
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentUser?.id;
});

/// Incrementado após qualquer escrita: todas as leituras dependem dele e recarregam.
class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataRevisionProvider = NotifierProvider<DataRevision, int>(DataRevision.new);

/// "Hoje" (data de calendário). Recalculado a cada recarga de dados.
final todayProvider = Provider<DateTime>((ref) {
  ref.watch(dataRevisionProvider);
  return Dates.today();
});

/// `true` quando a última leitura veio do cache por falta de conexão.
class OfflineStatus extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final offlineProvider = NotifierProvider<OfflineStatus, bool>(OfflineStatus.new);
