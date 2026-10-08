import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cache/local_cache.dart';
import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart';

class AuthRepository {
  AuthRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithPassword(email: email.trim(), password: password));

  /// Retorna `true` se a conta já está ativa (sem confirmação de e-mail pendente).
  Future<bool> signUp({required String name, required String email, required String password}) async {
    final res = await _guard(
      () => _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
        emailRedirectTo: Env.authRedirect,
      ),
    );
    return res.session != null;
  }

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email.trim(), redirectTo: Env.authRedirect));

  Future<void> updatePassword(String password) => _guard(() => _auth.updateUser(UserAttributes(password: password)));

  Future<void> updateName(String name) async {
    final id = currentUser?.id;
    if (id == null) return;
    await _guard(() async {
      await _client.from('profiles').update({'name': name.trim()}).eq('id', id);
      await _auth.updateUser(UserAttributes(data: {'name': name.trim()}));
    });
  }

  Future<void> signOut() async {
    await _cache.clear();
    try {
      await _auth.signOut();
    } catch (_) {
      // Sem conexão: a sessão local é removida mesmo assim.
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
