import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache simples de leitura offline: guarda o último JSON recebido por chave.
/// As chaves são prefixadas pelo id do usuário para isolar contas no mesmo aparelho.
class LocalCache {
  LocalCache(this._prefs);

  final SharedPreferences _prefs;
  static const _prefix = 'cache:';

  String _key(String userId, String key) => '$_prefix$userId:$key';

  Future<void> write(String userId, String key, Object? json) async {
    await _prefs.setString(_key(userId, key), jsonEncode(json));
  }

  Object? read(String userId, String key) {
    final raw = _prefs.getString(_key(userId, key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  /// Remove todo o cache (chamado ao sair da conta).
  Future<void> clear() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
