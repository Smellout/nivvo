import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cache/local_cache.dart';
import '../../core/errors/app_exception.dart';

/// Funcionalidade comum: leitura com fallback para cache e tradução de erros.
abstract class RepositoryBase {
  RepositoryBase({required this.client, required this.cache, required this.onOffline});

  final SupabaseClient client;
  final LocalCache cache;
  final void Function(bool offline) onOffline;

  String get userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AppException('Sua sessão expirou. Entre novamente.');
    return id;
  }

  /// Busca na API; em caso de falha de rede, devolve o último resultado salvo.
  /// Passe `cacheKey: null` para leituras que não devem ser guardadas (ex.: buscas).
  Future<Object?> read(String? cacheKey, Future<Object?> Function() fetch) async {
    try {
      final data = await fetch();
      onOffline(false);
      if (cacheKey != null) await cache.write(userId, cacheKey, data);
      return data;
    } catch (error) {
      if (AppException.isNetworkError(error)) {
        onOffline(true);
        final cached = cacheKey == null ? null : cache.read(userId, cacheKey);
        if (cached != null) return cached;
      }
      throw AppException.from(error);
    }
  }

  /// Escritas exigem conexão e nunca usam cache.
  Future<T> write<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      onOffline(false);
      return result;
    } catch (error) {
      if (AppException.isNetworkError(error)) onOffline(true);
      throw AppException.from(error);
    }
  }

  static List<Map<String, dynamic>> rows(Object? data) =>
      (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();

  static Map<String, dynamic> row(Object? data) => (data as Map).cast<String, dynamic>();

  /// Remove caracteres com significado nos filtros do PostgREST.
  static String sanitizeSearch(String q) => q.replaceAll(RegExp(r'''[,()*%:\\"'.]'''), ' ').trim();
}
