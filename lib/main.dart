import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'demo/demo_mode.dart';
import 'features/notifications/reminder_service.dart';
import 'features/settings/settings_controller.dart';
import 'shared/services/core_providers.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  if (Env.demo) {
    final prefs = await SharedPreferences.getInstance();
    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...demoOverrides(prefs)],
        retry: (_, _) => null,
        child: const NivvoApp(),
      ),
    );
    return;
  }

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  final results = await Future.wait<Object?>([
    SharedPreferences.getInstance(),
    Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseKey),
  ]);

  final prefs = results[0]! as SharedPreferences;
  final auth = Supabase.instance.client.auth;
  if (prefs.getBool(SettingsController.kKeepSignedIn) == false && auth.currentSession != null) {
    try {
      await auth.signOut();
    } catch (_) {
      // Offline: a sessão local é removida mesmo assim.
    }
  }

  try {
    await ReminderService.instance.init();
  } catch (e) {
    // Lembretes são complementares: o app funciona mesmo se o agendador falhar.
    debugPrint('Lembretes indisponíveis: $e');
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      // Erros aparecem na hora (com "Tentar de novo"), sem novas tentativas automáticas.
      retry: (_, _) => null,
      child: const NivvoApp(),
    ),
  );
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Configure SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY.\n\n'
              'flutter run --dart-define-from-file=env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
