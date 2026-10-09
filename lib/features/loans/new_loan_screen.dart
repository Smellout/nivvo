import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/finance/loan_calculator.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/validators.dart';
import '../../shared/models/client.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/aurora.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/money_input.dart';
import '../../theme/app_colors.dart';
import '../clients/client_sheets.dart';
import '../clients/clients_providers.dart';
import '../settings/settings_controller.dart';

/// Fluxo principal do Nivvo: cliente → valor → juros → prazo → confirmar.
/// Tudo em uma tela, com prévia ao vivo e foco avançando sozinho (~30s).
class NewLoanScreen extends ConsumerStatefulWidget {
  const NewLoanScreen({super.key, this.clientId});

  /// Pré-seleciona o cliente (ex.: "Nova operação" a partir da ficha do cliente).
  final String? clientId;

  @override
  ConsumerState<NewLoanScreen> createState() => _NewLoanScreenState();
}

class _NewLoanScreenState extends ConsumerState<NewLoanScreen> {
  static const _quickRates = [1000, 1500, 2000, 3000];
  static const _quickTerms = [7, 15, 30];

  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _term = TextEditingController();
  final _notes = TextEditingController();
  final _amountFocus = FocusNode();
  final _rateFocus = FocusNode();
  final _termFocus = FocusNode();

  Client? _client;
  int _principalCents = 0;
  int? _rateHundredths;
  int? _termDays;
  DateTime _startDate = Dates.today();
  bool _showNotes = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _rateHundredths = settings.lastRateHundredths;
    _termDays = settings.lastTermDays ?? 30;
    if (_rateHundredths != null) _rate.text = Rate.formatInput(_rateHundredths!);
    _term.text = '$_termDays';
    if (widget.clientId != null) _loadInitialClient(widget.clientId!);
  }

  Future<void> _loadInitialClient(String id) async {
    try {
      final summary = await ref.read(clientsRepositoryProvider).get(id);
      if (mounted) setState(() => _client = summary.client);
      _amountFocus.requestFocus();
    } catch (_) {
      // Sem o cliente pré-selecionado o usuário escolhe normalmente.
    }
  }

  @override
  void dispose() {
    for (final c in [_amount, _rate, _term, _notes]) {
      c.dispose();
    }
    for (final f in [_amountFocus, _rateFocus, _termFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  LoanQuote? get _quote {
    if (_principalCents <= 0 || _rateHundredths == null || _termDays == null) return null;
    if (_termDays! < 1 || _termDays! > LoanCalculator.maxTermDays) return null;
    if (_rateHundredths! > LoanCalculator.maxRateHundredths) return null;
    return LoanCalculator.quote(
      principalCents: _principalCents,
      rateHundredths: _rateHundredths!,
      termDays: _termDays!,
      startDate: _startDate,
    );
  }

  bool get _canConfirm => _client != null && _quote != null && !_busy;

  Future<void> _pickClient() async {
    final selected = await showClientPicker(context);
    if (selected == null || !mounted) return;
    setState(() => _client = selected);
    if (_principalCents == 0) _amountFocus.requestFocus();
  }

  Future<void> _newClient() async {
    final created = await showClientForm(context);
    if (created == null || !mounted) return;
    setState(() => _client = created);
    _amountFocus.requestFocus();
  }

  void _setRate(int hundredths) {
    setState(() {
      _rateHundredths = hundredths;
      _rate.text = Rate.formatInput(hundredths);
    });
    _termFocus.requestFocus();
  }

  void _setTerm(int days) {
    setState(() {
      _termDays = days;
      _term.text = '$days';
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickStartDate() async {
    final today = Dates.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: Dates.addDays(today, -3650),
      lastDate: today,
      helpText: 'Data da operação',
    );
    if (picked != null) setState(() => _startDate = Dates.dateOnly(picked));
  }

  Future<void> _confirm() async {
    final quote = _quote;
    final client = _client;
    if (quote == null || client == null) return;
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(loansRepositoryProvider)
          .create(clientId: client.id, quote: quote, notes: _notes.text.trim().isEmpty ? null : _notes.text.trim());
      await ref
          .read(settingsProvider.notifier)
          .rememberLoanDefaults(rateHundredths: quote.rateHundredths, termDays: quote.termDays);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      AppFeedback.success(context, 'Operação criada para ${client.name}');
      context.pushReplacement('/loan/$id');
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final quote = _quote;

    return NivvoScaffold(
      appBar: AppBar(
        title: const Text('Nova operação'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.pop()),
      ),
      // O botão fica no corpo (não em bottomNavigationBar) para subir junto com o teclado.
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                const _StepLabel(number: 1, label: 'Cliente'),
                _ClientSection(
                  client: _client,
                  onPick: _pickClient,
                  onNew: _newClient,
                  onSelect: (cl) {
                    setState(() => _client = cl);
                    _amountFocus.requestFocus();
                  },
                ),
                const _StepLabel(number: 2, label: 'Valor fornecido'),
                MoneyField(
                  controller: _amount,
                  focusNode: _amountFocus,
                  large: true,
                  onChanged: (cents) => setState(() => _principalCents = cents),
                  onSubmitted: () => _rateFocus.requestFocus(),
                ),
                const _StepLabel(number: 3, label: 'Juros da operação'),
                TextField(
                  controller: _rate,
                  focusNode: _rateFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [RateInputFormatter()],
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '0',
                    suffixText: '%',
                    suffixStyle: TextStyle(color: c.textSecondary, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (t) => setState(() => _rateHundredths = Rate.parse(t)),
                  onSubmitted: (_) => _termFocus.requestFocus(),
                ),
                const SizedBox(height: 8),
                _QuickChips<int>(
                  values: _quickRates,
                  selected: _rateHundredths,
                  label: Rate.format,
                  onSelected: _setRate,
                ),
                const _StepLabel(number: 4, label: 'Prazo'),
                TextField(
                  controller: _term,
                  focusNode: _termFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 4,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '30',
                    counterText: '',
                    suffixText: 'dias',
                    suffixStyle: TextStyle(color: c.textSecondary, fontSize: 16),
                  ),
                  onChanged: (t) => setState(() => _termDays = int.tryParse(Validators.digitsOnly(t))),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _QuickChips<int>(
                        values: _quickTerms,
                        selected: _termDays,
                        label: (d) => '$d dias',
                        onSelected: _setTerm,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickStartDate,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(
                      Dates.daysBetween(Dates.today(), _startDate) == 0
                          ? 'Data da operação: hoje'
                          : 'Data da operação: ${Dates.short(_startDate)}',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _Preview(quote: quote),
                const SizedBox(height: 12),
                if (_showNotes)
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    minLines: 2,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Observação'),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showNotes = true),
                      icon: const Icon(Icons.notes_rounded, size: 18),
                      label: const Text('Adicionar observação'),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: _canConfirm ? _confirm : null,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(quote == null ? 'Confirmar operação' : 'Confirmar · ${Money.format(quote.totalCents)}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.brand.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Text(
              '$number',
              style: TextStyle(color: c.brand, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ClientSection extends ConsumerWidget {
  const _ClientSection({required this.client, required this.onPick, required this.onNew, required this.onSelect});

  final Client? client;
  final VoidCallback onPick;
  final VoidCallback onNew;
  final ValueChanged<Client> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    if (client != null) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: InitialsAvatar(client!.initials),
          title: Text(client!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: client!.phone == null ? null : Text(Formatters.phone(client!.phone)),
          trailing: TextButton(onPressed: onPick, child: const Text('Trocar')),
        ),
      );
    }

    final recent = ref.watch(recentClientsProvider).value ?? const <Client>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Buscar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Novo cliente'),
              ),
            ),
          ],
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Recentes', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final r in recent)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: CircleAvatar(
                        backgroundColor: c.brand.withValues(alpha: 0.16),
                        child: Text(r.initials, style: TextStyle(fontSize: 10, color: c.brand)),
                      ),
                      label: Text(r.name.split(' ').first),
                      onPressed: () => onSelect(r),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickChips<T> extends StatelessWidget {
  const _QuickChips({required this.values, required this.selected, required this.label, required this.onSelected});

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            labelStyle: TextStyle(color: v == selected ? Colors.white : c.text, fontWeight: FontWeight.w700),
            onSelected: (_) => onSelected(v),
          ),
      ],
    );
  }
}

/// Prévia em tempo real do cálculo — mesmo resultado que o banco vai gravar.
class _Preview extends StatelessWidget {
  const _Preview({required this.quote});

  final LoanQuote? quote;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = quote;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: q == null ? c.border : c.brand.withValues(alpha: 0.5)),
      ),
      child: q == null
          ? Row(
              children: [
                Icon(Icons.calculate_outlined, color: c.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Informe valor, juros e prazo para ver o cálculo.',
                    style: TextStyle(color: c.textSecondary),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                KeyValueRow('Valor', Money.format(q.principalCents)),
                KeyValueRow('Juros', Rate.format(q.rateHundredths)),
                KeyValueRow('Juros calculados', '+ ${Money.format(q.interestCents)}'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider()),
                KeyValueRow('Total', Money.format(q.totalCents), emphasize: true),
                KeyValueRow(
                  'Vencimento',
                  '${Dates.short(q.dueDate)} · em ${q.termDays} ${q.termDays == 1 ? 'dia' : 'dias'}',
                ),
              ],
            ),
    );
  }
}
