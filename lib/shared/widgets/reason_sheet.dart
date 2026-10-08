import 'package:material_ui/material_ui.dart';

import '../../core/utils/validators.dart';
import '../../theme/app_colors.dart';

/// Pede o motivo de um cancelamento/estorno. Retorna o texto ou null.
Future<String?> showReasonSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReasonSheet(title: title, message: message, confirmLabel: confirmLabel),
  );
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({required this.title, required this.message, required this.confirmLabel});

  final String title;
  final String message;
  final String confirmLabel;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: context.text.titleLarge),
            const SizedBox(height: 8),
            Text(widget.message, style: TextStyle(color: c.textSecondary)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              autofocus: true,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Motivo'),
              validator: Validators.reason,
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c.danger),
              onPressed: () {
                if (_form.currentState!.validate()) Navigator.pop(context, _reason.text.trim());
              },
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      ),
    );
  }
}
