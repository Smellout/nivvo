import '../../core/money/money.dart';
import '../../core/utils/dates.dart';

class Client {
  const Client({required this.id, required this.name, this.phone, this.cpf, this.notes, required this.createdAt});

  final String id;
  final String name;
  final String? phone;
  final String? cpf;
  final String? notes;
  final DateTime createdAt;

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    cpf: json['cpf'] as String?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// Cliente com totais agregados (view `client_summary`).
class ClientSummary {
  const ClientSummary({
    required this.client,
    required this.totalLentCents,
    required this.totalReceivedCents,
    required this.balanceCents,
    required this.loansCount,
    required this.overdueCount,
  });

  final Client client;
  final int totalLentCents;
  final int totalReceivedCents;
  final int balanceCents;
  final int loansCount;
  final int overdueCount;

  factory ClientSummary.fromJson(Map<String, dynamic> json) => ClientSummary(
    client: Client.fromJson(json),
    totalLentCents: Money.fromJson(json['total_lent']),
    totalReceivedCents: Money.fromJson(json['total_received']),
    balanceCents: Money.fromJson(json['balance']),
    loansCount: (json['loans_count'] as num).toInt(),
    overdueCount: (json['overdue_count'] as num).toInt(),
  );
}

/// Dados para criar/editar cliente (já normalizados: só dígitos em telefone/CPF).
class ClientInput {
  const ClientInput({required this.name, this.phone, this.cpf, this.notes});

  final String name;
  final String? phone;
  final String? cpf;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'phone': _blankToNull(phone),
    'cpf': _blankToNull(cpf),
    'notes': _blankToNull(notes),
  };

  static String? _blankToNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
}

/// Exposto para os formulários formatarem a data de cadastro.
String clientSince(Client c) => 'Cliente desde ${Dates.short(c.createdAt.toLocal())}';
