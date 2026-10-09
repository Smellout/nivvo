import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/validators.dart';
import '../../shared/models/client.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/aurora.dart';
import '../../shared/widgets/common.dart';
import '../../theme/app_colors.dart';
import 'client_sheets.dart';

/// Cadastro (sem [clientId]) e edição (com [clientId]) de cliente.
/// Ao salvar, devolve o [Client] para quem abriu a tela (`context.push<Client>`).
class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({super.key, this.clientId, this.initialName});

  final String? clientId;
  final String? initialName;

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _cpf = TextEditingController();
  final _notes = TextEditingController();
  ClientSummary? _loaded;
  bool _busy = false;

  bool get _isEdit => widget.clientId != null;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    try {
      final summary = await ref.read(clientsRepositoryProvider).get(widget.clientId!);
      if (!mounted) return;
      final c = summary.client;
      setState(() {
        _loaded = summary;
        _name.text = c.name;
        _phone.text = c.phone == null ? '' : Formatters.phone(c.phone);
        _cpf.text = c.cpf == null ? '' : Formatters.cpf(c.cpf);
        _notes.text = c.notes ?? '';
      });
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    }
  }

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
      final saved = _isEdit ? await repo.update(widget.clientId!, input) : await repo.create(input);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      AppFeedback.success(context, _isEdit ? 'Cliente atualizado' : 'Cliente cadastrado');
      context.pop(saved);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final summary = _loaded;
    if (summary == null) return;
    final deleted = await confirmAndDeleteClient(context, ref, summary);
    if (deleted && mounted) context.go('/clients');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loading = _isEdit && _loaded == null;

    return NivvoScaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar cliente' : 'Novo cliente'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.pop()),
      ),
      // O botão Salvar fica fixo no corpo para subir junto com o teclado.
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : Column(
              children: [
                Expanded(
                  child: Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        TextFormField(
                          controller: _name,
                          autofocus: !_isEdit,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Nome completo'),
                          validator: Validators.name,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: const [phoneMask],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
                          validator: Validators.phone,
                        ),
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
                          maxLines: 4,
                          minLines: 3,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(labelText: 'Observações (opcional)'),
                        ),
                        if (_isEdit) ...[
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.danger,
                              side: BorderSide(color: c.danger.withValues(alpha: 0.5)),
                            ),
                            onPressed: _busy ? null : _delete,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Excluir cliente'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : Text(_isEdit ? 'Salvar alterações' : 'Salvar cliente'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Pede confirmação e exclui o cliente. Retorna `true` se excluiu.
/// Clientes com operações não podem ser excluídos (o histórico financeiro é preservado).
Future<bool> confirmAndDeleteClient(BuildContext context, WidgetRef ref, ClientSummary summary) async {
  final c = context.colors;
  final client = summary.client;

  if (summary.loansCount > 0) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.lock_outline_rounded, color: c.warning),
        title: const Text('Não é possível excluir'),
        content: Text(
          '${client.name} possui ${summary.loansCount} '
          '${summary.loansCount == 1 ? 'operação registrada' : 'operações registradas'}. '
          'Para preservar o histórico financeiro, clientes com operações não podem ser excluídos.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi'))],
      ),
    );
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: c.danger, size: 32),
      title: const Text('Excluir cliente?'),
      content: Text(
        'Tem certeza que deseja excluir ${client.name} permanentemente? '
        'Todos os dados deste cliente serão apagados e essa ação não pode ser desfeita.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.danger, minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Excluir permanentemente'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    await ref.read(clientsRepositoryProvider).delete(client.id);
    ref.read(dataRevisionProvider.notifier).bump();
    if (context.mounted) AppFeedback.success(context, '${client.name} foi excluído');
    return true;
  } catch (e) {
    if (context.mounted) AppFeedback.error(context, e);
    return false;
  }
}
