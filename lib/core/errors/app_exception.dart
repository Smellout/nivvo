import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Erro já traduzido para exibir ao usuário.
class AppException implements Exception {
  const AppException(this.message, {this.isNetwork = false});

  final String message;
  final bool isNetwork;

  @override
  String toString() => message;

  static const _rpcMessages = {
    'not_authenticated': 'Sua sessão expirou. Entre novamente.',
    'client_not_found': 'Cliente não encontrado.',
    'loan_not_found': 'Operação não encontrada.',
    'charge_not_found': 'Encargo não encontrado.',
    'payment_not_found': 'Pagamento não encontrado.',
    'invalid_amount': 'Valor inválido.',
    'invalid_rate': 'Taxa de juros inválida.',
    'invalid_term': 'Prazo inválido.',
    'invalid_date': 'Data inválida para esta operação.',
    'invalid_type': 'Tipo de encargo inválido.',
    'invalid_method': 'Forma de pagamento inválida.',
    'amount_exceeds_balance': 'O valor é maior que o saldo da operação.',
    'loan_cancelled': 'Esta operação está cancelada.',
    'loan_already_paid': 'Esta operação já está quitada.',
    'loan_has_payments': 'Operações com pagamentos não podem ser canceladas. Estorne os pagamentos antes.',
    'already_cancelled': 'Este lançamento já foi cancelado.',
    'reason_required': 'Informe o motivo.',
    'balance_would_be_negative': 'Não é possível cancelar: o saldo ficaria negativo. Estorne um pagamento antes.',
    'immutable_field': 'Este campo não pode ser alterado.',
    'invalid_timezone': 'Fuso horário inválido.',
  };

  static bool isNetworkError(Object error) {
    if (error is SocketException || error is TimeoutException || error is HttpException) return true;
    if (error is AuthRetryableFetchException) return true;
    if (error is AppException) return error.isNetwork;
    // ClientException (package:http) sem importar o pacote.
    final text = error.toString();
    return text.contains('ClientException') ||
        text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection closed') ||
        text.contains('Connection refused');
  }

  static AppException from(Object error) {
    if (error is AppException) return error;
    if (isNetworkError(error)) {
      return const AppException('Sem conexão. Verifique a internet e tente novamente.', isNetwork: true);
    }
    if (error is PostgrestException) {
      final known = _rpcMessages[error.message];
      if (known != null) return AppException(known);
      if (error.code == '23505' && error.message.contains('cpf')) {
        return const AppException('Já existe um cliente com este CPF.');
      }
      if (error.code == '23503') {
        return const AppException(
          'Este cliente possui operações registradas e não pode ser excluído. '
          'O histórico financeiro é preservado.',
        );
      }
      if (error.code == '23514') return const AppException('Dados inválidos.');
      if (error.code == '42501' || error.code == 'PGRST301') {
        return const AppException('Sem permissão. Entre novamente.');
      }
      return const AppException('Não foi possível concluir. Tente novamente.');
    }
    if (error is AuthException) return AppException(_authMessage(error));
    return const AppException('Algo deu errado. Tente novamente.');
  }

  static String _authMessage(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == 'invalid_credentials' || msg.contains('invalid login')) return 'E-mail ou senha incorretos.';
    if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
      return 'Confirme seu e-mail pelo link enviado antes de entrar.';
    }
    if (code == 'user_already_exists' || msg.contains('already registered')) {
      return 'Este e-mail já possui conta.';
    }
    if (code == 'weak_password') return 'Senha fraca. Use ao menos 8 caracteres com letras e números.';
    if (code == 'over_email_send_rate_limit' || code == 'over_request_rate_limit') {
      return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
    }
    if (code == 'same_password') return 'A nova senha deve ser diferente da atual.';
    return 'Não foi possível autenticar. Tente novamente.';
  }
}
