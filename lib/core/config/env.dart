/// Configuração injetada em tempo de build:
///   flutter run --dart-define-from-file=env.json
/// Nunca coloque a chave `service_role` aqui — apenas a chave pública (publishable/anon).
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Deep link de retorno dos e-mails de autenticação (ver AndroidManifest).
  static const authRedirect = 'com.nivvo.app://auth-callback';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
