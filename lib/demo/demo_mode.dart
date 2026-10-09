import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cache/local_cache.dart';
import '../core/finance/loan_calculator.dart';
import '../shared/models/charge.dart';
import '../shared/models/client.dart';
import '../shared/models/loan.dart';
import '../shared/models/payment.dart';
import '../shared/models/summaries.dart';
import '../shared/repositories/auth_repository.dart';
import '../shared/repositories/clients_repository.dart';
import '../shared/repositories/loans_repository.dart';
import '../shared/repositories/reports_repository.dart';
import '../shared/repositories/repository_providers.dart';
import '../shared/services/core_providers.dart';
import 'demo_store.dart';

/// Modo demonstração (`--dart-define=DEMO=true`): o app roda sem Supabase,
/// com dados fictícios em memória. Útil para prévia no navegador.
List<Override> demoOverrides(SharedPreferences prefs) {
  final store = DemoStore();
  // Cliente "vazio" só para satisfazer os construtores; nenhuma chamada de rede é feita.
  final client = SupabaseClient(
    'https://demo.invalid',
    'demo',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final cache = LocalCache(prefs);

  return [
    supabaseProvider.overrideWithValue(client),
    userProfileProvider.overrideWithValue((name: 'Daniel', email: 'demo@nivvo.app')),
    authRepositoryProvider.overrideWithValue(_DemoAuthRepository(client, cache)),
    clientsRepositoryProvider.overrideWithValue(_DemoClientsRepository(store, client, cache)),
    loansRepositoryProvider.overrideWithValue(_DemoLoansRepository(store, client, cache)),
    reportsRepositoryProvider.overrideWithValue(_DemoReportsRepository(store, client, cache)),
  ];
}

/// Pequena espera para a interface se comportar como com rede real.
Future<T> _later<T>(T Function() action) =>
    Future<void>.delayed(const Duration(milliseconds: 120)).then((_) => action());

class _DemoAuthRepository extends AuthRepository {
  _DemoAuthRepository(super.client, super.cache);

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<bool> signUp({required String name, required String email, required String password}) async => true;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> updateName(String name) async {}

  @override
  Future<void> signOut() async {}
}

class _DemoClientsRepository extends ClientsRepository {
  _DemoClientsRepository(this.store, SupabaseClient client, LocalCache cache)
    : super(client: client, cache: cache, onOffline: (_) {});

  final DemoStore store;

  @override
  Future<List<ClientSummary>> list({String query = '', int offset = 0, int limit = ClientsRepository.pageSize}) =>
      _later(() => store.clients(query: query, offset: offset, limit: limit));

  @override
  Future<List<Client>> recent({int limit = 8}) => _later(() => store.recentClients(limit: limit));

  @override
  Future<ClientSummary> get(String id) => _later(() => store.clientSummary(id));

  @override
  Future<Client> create(ClientInput input) => _later(() => store.createClient(input));

  @override
  Future<Client> update(String id, ClientInput input) => _later(() => store.updateClient(id, input));

  @override
  Future<void> delete(String id) => _later(() => store.deleteClient(id));
}

class _DemoLoansRepository extends LoansRepository {
  _DemoLoansRepository(this.store, SupabaseClient client, LocalCache cache)
    : super(client: client, cache: cache, onOffline: (_) {});

  final DemoStore store;

  @override
  Future<DashboardSummary> dashboard() => _later(store.dashboard);

  @override
  Future<List<Loan>> upcoming(DateTime today, {int limit = 6}) => _later(() => store.upcoming(today, limit: limit));

  @override
  Future<List<Loan>> list({
    required LoanFilter filter,
    required DateTime today,
    String query = '',
    String? clientId,
    int offset = 0,
    int limit = LoansRepository.pageSize,
  }) => _later(
    () => store.loans(filter: filter, today: today, query: query, clientId: clientId, offset: offset, limit: limit),
  );

  @override
  Future<LoanDetail> detail(String loanId) => _later(() => store.detail(loanId));

  @override
  Future<List<Loan>> activeDueBetween(DateTime from, DateTime until) =>
      _later(() => store.activeDueBetween(from, until));

  @override
  Future<String> create({required String clientId, required LoanQuote quote, String? notes}) =>
      _later(() => store.createLoan(clientId: clientId, quote: quote, notes: notes));

  @override
  Future<void> registerPayment({
    required String loanId,
    required int amountCents,
    required PaymentMethod method,
    required DateTime date,
    String? notes,
  }) => _later(
    () => store.registerPayment(loanId: loanId, amountCents: amountCents, method: method, date: date, notes: notes),
  );

  @override
  Future<void> addCharge({
    required String loanId,
    required ChargeType type,
    required int amountCents,
    required DateTime date,
    String? description,
  }) => _later(
    () => store.addCharge(loanId: loanId, type: type, amountCents: amountCents, date: date, description: description),
  );

  @override
  Future<void> cancelCharge(String chargeId, String reason) => _later(() => store.cancelCharge(chargeId, reason));

  @override
  Future<void> cancelPayment(String paymentId, String reason) => _later(() => store.cancelPayment(paymentId, reason));

  @override
  Future<void> cancelLoan(String loanId, String reason) => _later(() => store.cancelLoan(loanId, reason));
}

class _DemoReportsRepository extends ReportsRepository {
  _DemoReportsRepository(this.store, SupabaseClient client, LocalCache cache)
    : super(client: client, cache: cache, onOffline: (_) {});

  final DemoStore store;

  @override
  Future<ReportSummary> summary(DateTime from, DateTime to) => _later(() => store.report(from, to));
}
