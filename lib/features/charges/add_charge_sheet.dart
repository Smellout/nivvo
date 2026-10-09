import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../../shared/models/charge.dart';
import '../../shared/models/loan.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/money_input.dart';
import '../../theme/app_colors.dart';

/// Lançamento manual de encargo (o Nivvo nunca calcula atraso sozinho).
Future<bool?> showAddCharge(BuildContext context, Loan loan) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddChargeSheet(loan: loan),
  );
}

class _AddChargeSheet extends ConsumerStatefulWidget {
  const _AddChargeSheet({required this.loan});

  final Loan loan;

  @override
  ConsumerState<_AddChargeSheet> createState() => _AddChargeSheetState();
}

class _AddChargeSheetState extends ConsumerState<_AddChargeSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  ChargeType _type = ChargeType.lateInterest;
  int _cents = 0;
  DateTime _date = Dates.today();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.loan.startDate,
      lastDate: Dates.today(),
      helpText: 'Data do encargo',
    );
    if (picked != null) setState(() => _date = Dates.dateOnly(picked));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(loansRepositoryProvider)
          .addCharge(
            loanId: widget.loan.id,
            type: _type,
            amountCents: _cents,
            date: _date,
            description: _description.text.trim().isEmpty ? null : _description.text.trim(),
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
    final loan = widget.loan;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Lançar encargo', style: context.text.titleLarge),
              const SizedBox(height: 4),
              Text('Saldo atual ${Money.format(loan.remainingCents)}', style: TextStyle(color: c.textSecondary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in ChargeType.values)
                    ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      labelStyle: TextStyle(color: _type == t ? Colors.white : c.text, fontWeight: FontWeight.w700),
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              MoneyField(
                controller: _amount,
                autofocus: true,
                large: true,
                label: 'Valor',
                onChanged: (v) => setState(() => _cents = v),
                validator: (v) => v <= 0 ? 'Informe o valor' : null,
              ),
              if (_cents > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Total atualizado: ${Money.format(loan.totalUpdatedCents + _cents)} · '
                  'novo saldo ${Money.format(loan.remainingCents + _cents)}',
                  style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 8),
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
                controller: _description,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Descrição (opcional)', counterText: ''),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Lançar encargo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
