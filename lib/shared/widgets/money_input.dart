import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money/money.dart';
import '../../theme/app_colors.dart';

/// Digitação estilo app bancário: os dígitos entram pelos centavos (3 → 0,03 → 0,30 → 3,00).
class CurrencyInputFormatter extends TextInputFormatter {
  const CurrencyInputFormatter({this.maxCents = 99999999999});

  final int maxCents;

  static int centsOf(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? 0 : int.parse(digits);
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final trimmed = digits.length > 13 ? digits.substring(0, 13) : digits;
    final cents = int.parse(trimmed);
    if (cents > maxCents) return oldValue;
    final text = Money.formatPlain(cents);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Taxa: até 3 dígitos inteiros e 2 decimais, vírgula como separador.
class RateInputFormatter extends TextInputFormatter {
  const RateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('.', ',');
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d{0,3}(,\d{0,2})?$').hasMatch(text)) return oldValue;
    return newValue.copyWith(text: text);
  }
}

/// Campo de valor em destaque (R$ grande).
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.label,
    this.large = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? label;
  final bool large;
  final ValueChanged<int>? onChanged;
  final VoidCallback? onSubmitted;
  final String? Function(int cents)? validator;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = large
        ? TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1, color: c.text)
        : TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.text);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      inputFormatters: const [CurrencyInputFormatter()],
      style: style,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0,00',
        hintStyle: style.copyWith(color: c.textSecondary.withValues(alpha: 0.6)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Text(
            r'R$',
            style: style.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      onChanged: (t) => onChanged?.call(CurrencyInputFormatter.centsOf(t)),
      onFieldSubmitted: (_) => onSubmitted?.call(),
      validator: validator == null ? null : (t) => validator!(CurrencyInputFormatter.centsOf(t ?? '')),
    );
  }
}
