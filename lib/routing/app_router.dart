import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_screens.dart';
import '../features/clients/client_detail_screen.dart';
import '../features/clients/clients_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/loans/loan_detail_screen.dart';
import '../features/loans/loans_screen.dart';
import '../features/loans/new_loan_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/settings_screen.dart';
import '../shared/services/core_providers.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(supabaseProvider).auth;
  final refresh = ValueNotifier<int>(0);

  final sub = auth.onAuthStateChange.listen((event) {
    final recovery = ref.read(passwordRecoveryProvider.notifier);
    if (event.event == AuthChangeEvent.passwordRecovery) recovery.set(true);
    if (event.event == AuthChangeEvent.signedOut) recovery.set(false);
    refresh.value++;
  });
  ref.listen(passwordRecoveryProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.currentSession != null;
      final recovering = ref.read(passwordRecoveryProvider);
      final loc = state.matchedLocation;
      final onAuthRoute = loc.startsWith('/auth');

      if (loggedIn && recovering) return loc == '/auth/reset' ? null : '/auth/reset';
      if (!loggedIn) return (onAuthRoute && loc != '/auth/reset') ? null : '/auth/login';
      if (onAuthRoute) return '/';
      return null;
    },
    errorBuilder: (context, state) => const _NotFound(),
    routes: [
      GoRoute(path: '/auth/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/auth/signup', builder: (_, _) => const SignUpScreen()),
      GoRoute(path: '/auth/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/auth/reset', builder: (_, _) => const ResetPasswordScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const DashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/loans',
                builder: (_, state) => LoansScreen(filterName: state.uri.queryParameters['filter']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/clients', builder: (_, _) => const ClientsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/new-loan',
        builder: (_, state) => NewLoanScreen(clientId: state.uri.queryParameters['clientId']),
      ),
      GoRoute(
        path: '/loan/:id',
        builder: (_, state) => LoanDetailScreen(loanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/client/:id',
        builder: (_, state) => ClientDetailScreen(clientId: state.pathParameters['id']!),
      ),
    ],
  );

  ref.onDispose(() {
    sub.cancel();
    refresh.dispose();
    router.dispose();
  });
  return router;
});

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: TextButton(onPressed: () => context.go('/'), child: const Text('Voltar ao início')),
      ),
    );
  }
}
