import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money/money.dart';
import '../../core/utils/validators.dart';
import '../../shared/models/client.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/common.dart';
import '../../theme/app_colors.dart';
import 'clients_providers.dart';

/// Máscara progressiva para telefone e CPF.
class _MaskFormatter extends TextInputFormatter {
  const _MaskFormatter(this.maskFor);

  final String Function(int digits) maskFor;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = Validators.digitsOnly(newValue.text);
    final mask = maskFor(digits.length);
    final maxDigits = '#'.allMatches(mask).length;
    final d = digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
    final out = StringBuffer();
    var i = 0;
    for (final ch in mask.split('')) {
      if (i >= d.length) break;
      if (ch == '#') {
        out.write(d[i++]);
      } else {
        out.write(ch);
      }
    }
    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

const phoneMask = _MaskFormatter(_phoneMask);
const cpfMask = _MaskFormatter(_cpfMask);

String _phoneMask(int n) => n <= 10 ? '(##) ####-####' : '(##) #####-####';
String _cpfMask(int _) => '###.###.###-##';

/// Cadastro/edição de cliente em bottom sheet. Retorna o [Client] salvo.
Future<Client?> showClientForm(BuildContext context, {Client? client, String? initialName}) {
  return showModalBottomSheet<Client>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ClientForm(client: client, initialName: initialName),
  );
}

class _ClientForm extends ConsumerStatefulWidget {
  const _ClientForm({this.client, this.initialName});

  final Client? client;
  final String? initialName;

  @override
  ConsumerState<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<_ClientForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.client?.name ?? widget.initialName ?? '');
  late final _phone = TextEditingController(
    text: widget.client?.phone == null ? '' : Formatters.phone(widget.client!.phone),
  );
  late final _cpf = TextEditingController(text: widget.client?.cpf == null ? '' : Formatters.cpf(widget.client!.cpf));
  late final _notes = TextEditingController(text: widget.client?.notes ?? '');
  late bool _showMore = widget.client != null && (widget.client!.cpf != null || widget.client!.notes != null);
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _cpf, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final input = ClientInput(
      name: _name.text,
      phone: Validators.digitsOnly(_phone.text),
      cpf: Validators.digitsOnly(_cpf.text),
      notes: _notes.text,
    );
    try {
      final repo = ref.read(clientsRepositoryProvider);
      final saved = widget.client == null ? await repo.create(input) : await repo.update(widget.client!.id, input);
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.client == null ? 'Novo cliente' : 'Editar cliente', style: context.text.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: widget.client == null,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: Validators.name,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: const [phoneMask],
                textInputAction: _showMore ? TextInputAction.next : TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
                validator: Validators.phone,
                onFieldSubmitted: (_) => _showMore ? null : _save(),
              ),
              if (!_showMore)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showMore = true),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('CPF e observações'),
                  ),
                )
              else ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cpf,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [cpfMask],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'CPF (opcional)'),
                  validator: Validators.cpf,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Observações'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.text))
                    : Text(widget.client == null ? 'Salvar cliente' : 'Salvar alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seletor de cliente com busca e "Novo cliente" sem sair do fluxo.
Future<Client?> showClientPicker(BuildContext context) {
  return showModalBottomSheet<Client>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(heightFactor: 0.88, child: _ClientPicker()),
  );
}

class _ClientPicker extends ConsumerStatefulWidget {
  const _ClientPicker();

  @override
  ConsumerState<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends ConsumerState<_ClientPicker> {
  String _query = '';
  String _typed = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _createNew() async {
    final created = await showClientForm(context, initialName: _typed.trim());
    if (created != null && mounted) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(clientSearchProvider(_query));
    final c = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(child: Text('Selecionar cliente', style: context.text.titleLarge)),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: _createNew,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Novo'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Nome, telefone ou CPF',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (t) {
              _typed = t;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) setState(() => _query = t.trim());
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AsyncBody(
            value: results,
            onRetry: () => ref.invalidate(clientSearchProvider(_query)),
            data: (clients) {
              if (clients.isEmpty) {
                return EmptyState(
                  icon: Icons.person_search_rounded,
                  title: _query.isEmpty ? 'Nenhum cliente ainda' : 'Nenhum cliente encontrado',
                  action: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _createNew,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(_typed.trim().isEmpty ? 'Cadastrar cliente' : 'Cadastrar "${_typed.trim()}"'),
                  ),
                );
              }
              return ListView.builder(
                itemCount: clients.length,
                itemBuilder: (context, i) {
                  final s = clients[i];
                  return ListTile(
                    leading: InitialsAvatar(s.client.initials, size: 40),
                    title: Text(s.client.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      s.balanceCents > 0
                          ? 'Em aberto: ${Money.format(s.balanceCents)}'
                          : (s.client.phone == null ? 'Sem operações em aberto' : Formatters.phone(s.client.phone)),
                      style: TextStyle(color: s.overdueCount > 0 ? c.danger : c.textSecondary),
                    ),
                    onTap: () => Navigator.pop(context, s.client),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
