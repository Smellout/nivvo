import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors/app_exception.dart';
import '../../theme/app_colors.dart';
import '../services/core_providers.dart';

/// Renderiza um AsyncValue com carregamento, erro (com "Tentar de novo") e dados.
/// Durante recargas mantém os dados anteriores na tela (sem piscar).
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data, this.onRetry, this.loading});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return data(value.requireValue);
    if (value.hasError) {
      return ErrorState(message: AppException.from(value.error!).message, onRetry: onRetry);
    }
    return loading ?? const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Não foi possível carregar',
      message: message,
      action: onRetry == null ? null : TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, color: c.textSecondary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

/// Aviso discreto quando os dados exibidos vieram do cache.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider);
    final c = context.colors;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: !offline
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: c.warning.withValues(alpha: 0.14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 16, color: c.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline — exibindo os últimos dados salvos',
                      style: TextStyle(color: c.warning, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.padding});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 24, 12, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleMedium)),
          ?trailing,
        ],
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials, {super.key, this.size = 42, this.color});

  final String initials;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = color ?? c.brand;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(size * 0.36)),
      child: Text(
        initials,
        style: TextStyle(color: tint, fontWeight: FontWeight.w700, fontSize: size * 0.36),
      ),
    );
  }
}

/// Linha "rótulo ........ valor".
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.valueStyle, this.emphasize = false});

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ),
          Text(
            value,
            style:
                valueStyle ??
                TextStyle(
                  color: c.text,
                  fontSize: emphasize ? 17 : 14.5,
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}

abstract final class AppFeedback {
  static void success(BuildContext context, String message) => _show(context, message, Icons.check_circle_rounded);

  static void error(BuildContext context, Object error) =>
      _show(context, AppException.from(error).message, Icons.error_outline_rounded, isError: true);

  static void _show(BuildContext context, String message, IconData icon, {bool isError = false}) {
    final c = context.colors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: isError ? c.danger : c.success, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
