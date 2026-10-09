import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../../shared/widgets/aurora.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/nivvo_logo.dart';
import '../../theme/app_colors.dart';
import '../notifications/reminder_service.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final profile = ref.watch(userProfileProvider);
    final name = profile.name;
    final c = context.colors;

    return NivvoScaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: InitialsAvatar(name.isEmpty ? '?' : name.trim()[0].toUpperCase(), size: 46),
                title: Text(name.isEmpty ? 'Seu perfil' : name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(profile.email),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _editName(context, ref, name),
              ),
            ),
          ),
          if (Env.demo)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.science_outlined, color: c.brand),
                  title: const Text('Modo demonstração'),
                  subtitle: const Text('Dados fictícios em memória. Nada é salvo.'),
                ),
              ),
            ),
          const SectionTitle('Aparência'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Escuro')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Claro')),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android_rounded), label: Text('Sistema')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => controller.setThemeMode(s.first),
            ),
          ),
          const SectionTitle('Lembretes de vencimento'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Avisar vencimentos'),
                    subtitle: const Text('7, 3 e 1 dia antes, no dia e após vencer (09:00)'),
                    value: settings.remindersEnabled,
                    onChanged: (v) async {
                      if (v) {
                        final granted = await ReminderService.instance.requestPermission();
                        if (!granted && context.mounted) {
                          AppFeedback.error(
                            context,
                            const AppException('Permita as notificações do Nivvo nas configurações do Android.'),
                          );
                        }
                      }
                      await controller.setRemindersEnabled(v);
                    },
                  ),
                  const Divider(indent: 16),
                  SwitchListTile(
                    title: const Text('Ocultar valores'),
                    subtitle: const Text('Não mostra valores na tela de bloqueio'),
                    value: settings.hideAmountsInReminders,
                    onChanged: settings.remindersEnabled ? controller.setHideAmounts : null,
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Conta'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.verified_user_outlined),
                    title: const Text('Manter conectado'),
                    subtitle: const Text('Não pedir login ao abrir o app'),
                    value: settings.keepSignedIn,
                    onChanged: controller.setKeepSignedIn,
                  ),
                  const Divider(indent: 16),
                  ListTile(
                    leading: const Icon(Icons.lock_reset_rounded),
                    title: const Text('Alterar senha'),
                    onTap: () async {
                      final email = profile.email;
                      if (email.isEmpty) return;
                      try {
                        await ref.read(authRepositoryProvider).sendPasswordReset(email);
                        if (context.mounted) AppFeedback.success(context, 'Enviamos um link para $email');
                      } catch (e) {
                        if (context.mounted) AppFeedback.error(context, e);
                      }
                    },
                  ),
                  const Divider(indent: 16),
                  ListTile(
                    leading: Icon(Icons.logout_rounded, color: c.danger),
                    title: Text('Sair', style: TextStyle(color: c.danger)),
                    onTap: () => _signOut(context, ref),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          const Center(child: NivvoWordmark(height: 26, showTagline: true)),
          const SizedBox(height: 8),
          Center(
            child: Text('Versão 0.1.0', style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seu nome'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            validator: Validators.name,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    try {
      await ref.read(authRepositoryProvider).updateName(name);
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, e);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Os dados salvos para uso offline serão apagados deste aparelho.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
        ],
      ),
    );
    if (confirm != true) return;
    await ReminderService.instance.cancelAll();
    await ref.read(authRepositoryProvider).signOut();
  }
}
