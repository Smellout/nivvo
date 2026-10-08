import '../../core/finance/loan_calculator.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../models/charge.dart';
import '../models/history_entry.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/summaries.dart';
import 'repository_base.dart';

enum LoanFilter {
  all('Todas'),
  pending('Pendentes'),
  dueSoon('Vencendo'),
  overdue('Vencidas'),
  paid('Pagas');

  const LoanFilter(this.label);
  final String label;

  static LoanFilter fromName(String? name) => values.firstWhere((f) => f.name == name, orElse: () => LoanFilter.all);
}

class LoansRepository extends RepositoryBase {
  LoansRepository({required super.client, required super.cache, required super.onOffline});

  static const pageSize = 25;

  // ---------------------------------------------------------------- leituras

  Future<DashboardSummary> dashboard() async {
    final data = await read('dashboard', () {
      return client.rpc('dashboard_summary', params: {'p_due_soon_days': LoanStatusRules.dueSoonDays});
    });
    return DashboardSummary.fromJson(RepositoryBase.row(data));
  }

  /// Próximos vencimentos (de hoje em diante).
  Future<List<Loan>> upcoming(DateTime today, {int limit = 6}) async {
    final data = await read('loans:upcoming', () {
      return client
          .from('loan_overview')
          .select()
          .eq('status', 'active')
          .gte('due_date', Dates.toJson(today))
          .order('due_date', ascending: true)
          .limit(limit);
    });
    return RepositoryBase.rows(data).map(Loan.fromJson).toList();
  }

  Future<List<Loan>> list({
    required LoanFilter filter,
    required DateTime today,
    String query = '',
    String? clientId,
    int offset = 0,
    int limit = pageSize,
  }) async {
    final q = RepositoryBase.sanitizeSearch(query);
    final cacheKey = (q.isEmpty && offset == 0) ? 'loans:${filter.name}:${clientId ?? '-'}' : null;
    final todayJson = Dates.toJson(today);

    final data = await read(cacheKey, () {
      var b = client.from('loan_overview').select();
      if (clientId != null) b = b.eq('client_id', clientId);
      switch (filter) {
        case LoanFilter.all:
          break;
        case LoanFilter.pending:
          b = b.eq('status', 'active').gte('due_date', todayJson);
        case LoanFilter.dueSoon:
          b = b
              .eq('status', 'active')
              .gte('due_date', todayJson)
              .lte('due_date', Dates.toJson(Dates.addDays(today, LoanStatusRules.dueSoonDays)));
        case LoanFilter.overdue:
          b = b.eq('status', 'active').lt('due_date', todayJson);
        case LoanFilter.paid:
          b = b.eq('status', 'paid');
      }
      if (q.isNotEmpty) {
        final digits = q.replaceAll(RegExp(r'\D'), '');
        b = digits.length >= 3
            ? b.or('client_name.ilike.*$q*,client_phone.ilike.*$digits*,client_cpf.ilike.*$digits*')
            : b.ilike('client_name', '*$q*');
      }
      final ordered = switch (filter) {
        LoanFilter.paid => b.order('paid_at', ascending: false),
        // Enum `loan_status` ordena active < paid < cancelled.
        LoanFilter.all => b.order('status', ascending: true).order('due_date', ascending: true),
        _ => b.order('due_date', ascending: true),
      };
      return ordered.order('created_at', ascending: false).range(offset, offset + limit - 1);
    });
    return RepositoryBase.rows(data).map(Loan.fromJson).toList();
  }

  Future<LoanDetail> detail(String loanId) async {
    final data = await read('loan:$loanId', () async {
      final results = await Future.wait<Object?>([
        client.from('loan_overview').select().eq('id', loanId).single(),
        client
            .from('loan_charges')
            .select()
            .eq('loan_id', loanId)
            .order('charge_date', ascending: true)
            .order('created_at', ascending: true),
        client
            .from('payments')
            .select()
            .eq('loan_id', loanId)
            .order('payment_date', ascending: true)
            .order('created_at', ascending: true),
        client.from('loan_history').select().eq('loan_id', loanId).order('created_at', ascending: true),
      ]);
      return {'loan': results[0], 'charges': results[1], 'payments': results[2], 'history': results[3]};
    });
    final map = RepositoryBase.row(data);
    return LoanDetail(
      loan: Loan.fromJson(RepositoryBase.row(map['loan'])),
      charges: RepositoryBase.rows(map['charges']).map(LoanCharge.fromJson).toList(),
      payments: RepositoryBase.rows(map['payments']).map(Payment.fromJson).toList(),
      history: RepositoryBase.rows(map['history']).map(HistoryEntry.fromJson).toList(),
    );
  }

  /// Operações ativas que vencem entre `from` e `until` — base dos lembretes locais.
  Future<List<Loan>> activeDueBetween(DateTime from, DateTime until) async {
    final data = await read('loans:reminders', () {
      return client
          .from('loan_overview')
          .select()
          .eq('status', 'active')
          .gte('due_date', Dates.toJson(from))
          .lte('due_date', Dates.toJson(until))
          .order('due_date', ascending: true)
          .limit(1000);
    });
    return RepositoryBase.rows(data).map(Loan.fromJson).toList();
  }

  // ---------------------------------------------------------------- escritas

  Future<String> create({required String clientId, required LoanQuote quote, String? notes}) {
    return write(() async {
      final data = await client.rpc(
        'create_loan',
        params: {
          'p_client_id': clientId,
          'p_principal': Money.toJson(quote.principalCents),
          'p_interest_rate': Rate.toJson(quote.rateHundredths),
          'p_term_days': quote.termDays,
          'p_start_date': Dates.toJson(quote.startDate),
          'p_notes': notes,
        },
      );
      return RepositoryBase.row(data)['id'] as String;
    });
  }

  Future<void> registerPayment({
    required String loanId,
    required int amountCents,
    required PaymentMethod method,
    required DateTime date,
    String? notes,
  }) {
    return write(
      () => client.rpc(
        'register_payment',
        params: {
          'p_loan_id': loanId,
          'p_amount': Money.toJson(amountCents),
          'p_method': method.json,
          'p_payment_date': Dates.toJson(date),
          'p_notes': notes,
        },
      ),
    );
  }

  Future<void> addCharge({
    required String loanId,
    required ChargeType type,
    required int amountCents,
    required DateTime date,
    String? description,
  }) {
    return write(
      () => client.rpc(
        'add_charge',
        params: {
          'p_loan_id': loanId,
          'p_type': type.json,
          'p_amount': Money.toJson(amountCents),
          'p_charge_date': Dates.toJson(date),
          'p_description': description,
        },
      ),
    );
  }

  Future<void> cancelCharge(String chargeId, String reason) {
    return write(() => client.rpc('cancel_charge', params: {'p_charge_id': chargeId, 'p_reason': reason}));
  }

  Future<void> cancelPayment(String paymentId, String reason) {
    return write(() => client.rpc('cancel_payment', params: {'p_payment_id': paymentId, 'p_reason': reason}));
  }

  Future<void> cancelLoan(String loanId, String reason) {
    return write(() => client.rpc('cancel_loan', params: {'p_loan_id': loanId, 'p_reason': reason}));
  }
}
