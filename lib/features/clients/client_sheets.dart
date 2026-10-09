import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money/money.dart';
import '../../core/utils/validators.dart';
import '../../shared/models/client.dart';
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

/// Abre a tela de cadastro (ou edição, com [client]) e devolve o cliente salvo.
Future<Client?> showClientForm(BuildContext context, {Client? client, String? initialName}) {
  if (client != null) return context.push<Client>('/client/${client.id}/edit');
  final name = initialName?.trim() ?? '';
  return context.push<Client>(
    Uri(path: '/client-form', queryParameters: name.isEmpty ? null : {'name': name}).toString(),
  );
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
