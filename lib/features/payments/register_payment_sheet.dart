import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../../shared/models/loan.dart';
import '../../shared/models/payment.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/money_input.dart';
import '../../theme/app_colors.dart';

/// Registra um recebimento (parcial ou quitação). Retorna `true` se salvou.
Future<bool?> showRegisterPayment(BuildContext context, Loan loan) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RegisterPaymentSheet(loan: loan),
  );
}

class _RegisterPaymentSheet extends ConsumerStatefulWidget {
  const _RegisterPaymentSheet({required this.loan});

  final Loan loan;

  @override
  ConsumerState<_RegisterPaymentSheet> createState() => _RegisterPaymentSheetState();
}

class _RegisterPaymentSheetState extends ConsumerState<_RegisterPaymentSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  int _cents = 0;
  PaymentMethod _method = PaymentMethod.pix;
  DateTime _date = Dates.today();
  bool _busy = false;

  Loan get loan => widget.loan;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _fillBalance() {
    _amount.text = Money.formatPlain(loan.remainingCents);
    setState(() => _cents = loan.remainingCents);
  }

  Future<void> _pickDate() async {
    final today = Dates.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: loan.startDate,
      lastDate: today,
      helpText: 'Data do recebimento',
    );
    if (picked != null) setState(() => _date = Dates.dateOnly(picked));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(loansRepositoryProvider)
          .registerPayment(
            loanId: loan.id,
            amountCents: _cents,
            method: _method,
            date: _date,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final newBalance = loan.remainingCents - _cents;
    final settles = _cents > 0 && newBalance == 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Registrar pagamento', style: context.text.titleLarge),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    KeyValueRow('Total atualizado', Money.format(loan.totalUpdatedCents)),
                    KeyValueRow('Pago', Money.format(loan.paidCents)),
                    KeyValueRow('Saldo', Money.format(loan.remainingCents), emphasize: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              MoneyField(
                controller: _amount,
                autofocus: true,
                large: true,
                label: 'Valor recebido',
                onChanged: (v) => setState(() => _cents = v),
                validator: (v) {
                  if (v <= 0) return 'Informe o valor recebido';
                  if (v > loan.remainingCents) return 'Maior que o saldo (${Money.format(loan.remainingCents)})';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ActionChip(
                    avatar: Icon(Icons.done_all_rounded, size: 18, color: c.success),
                    label: Text('Quitar ${Money.format(loan.remainingCents)}'),
                    onPressed: _fillBalance,
                  ),
                ],
              ),
              if (_cents > 0 && newBalance >= 0) ...[
                const SizedBox(height: 10),
                Text(
                  settles
                      ? 'Esta operação será quitada.'
                      : 'Novo saldo: ${Money.format(newBalance)} · pagamento parcial',
                  style: TextStyle(color: settles ? c.success : c.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 16),
              Text('Forma', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in PaymentMethod.values)
                    ChoiceChip(
                      avatar: Icon(m.icon, size: 18, color: _method == m ? c.brand : c.textSecondary),
                      label: Text(m.label),
                      selected: _method == m,
                      labelStyle: TextStyle(color: _method == m ? c.brand : c.text, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _method = m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: const Text('Data'),
                trailing: Text(
                  Dates.daysBetween(Dates.today(), _date) == 0 ? 'Hoje' : Dates.short(_date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: _pickDate,
              ),
              TextField(
                controller: _notes,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Observação (opcional)', counterText: ''),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: settles
                    ? FilledButton.styleFrom(backgroundColor: c.success, foregroundColor: Colors.black)
                    : null,
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : Text(settles ? 'Quitar operação' : 'Registrar pagamento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
