import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/validators.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/widgets/aurora.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/nivvo_logo.dart';
import '../../theme/app_colors.dart';
import '../settings/settings_controller.dart';

/// Verdadeiro enquanto o usuário veio do link "redefinir senha".
class PasswordRecovery extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final passwordRecoveryProvider = NotifierProvider<PasswordRecovery, bool>(PasswordRecovery.new);

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, this.subtitle, required this.children, this.showBack = false});

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return NivvoScaffold(
      aurora: 1,
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showBack) ...[
                    const Center(child: NivvoWordmark(height: 44, showTagline: true)),
                    const SizedBox(height: 40),
                  ],
                  FrostedGlass(
                    radius: 28,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: context.text.headlineSmall),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(subtitle!, style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
                        ],
                        const SizedBox(height: 22),
                        ...children,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    this.label = 'Senha',
    this.validator,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: widget.validator,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    );
  }
}

// ------------------------------------------------------------------ Login

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  late bool _keepSignedIn;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _keepSignedIn = settings.keepSignedIn;
    _email.text = settings.lastEmail ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signIn(email: _email.text, password: _password.text);
      final settings = ref.read(settingsProvider.notifier);
      await settings.setKeepSignedIn(_keepSignedIn);
      await settings.rememberEmail(_email.text);
      // O redirecionamento do router leva ao Início.
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Entrar',
      subtitle: 'Acesse sua carteira de operações.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _password,
                  validator: (v) => (v ?? '').isEmpty ? 'Informe a senha' : null,
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _keepSignedIn = !_keepSignedIn),
                child: Row(
                  children: [
                    Checkbox(
                      value: _keepSignedIn,
                      onChanged: (v) => setState(() => _keepSignedIn = v ?? true),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                    const Flexible(
                      child: Text('Manter conectado', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(onPressed: () => context.push('/auth/forgot'), child: const Text('Esqueci a senha')),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const _ButtonSpinner() : const Text('Entrar')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _busy ? null : () => context.push('/auth/signup'), child: const Text('Criar conta')),
      ],
    );
  }
}

// ------------------------------------------------------------------ Cadastro

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final active = await ref
          .read(authRepositoryProvider)
          .signUp(name: _name.text, email: _email.text, password: _password.text);
      if (!mounted) return;
      if (!active) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirme seu e-mail'),
            content: Text('Enviamos um link para ${_email.text.trim()}. Abra-o neste aparelho para ativar a conta.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi'))],
          ),
        );
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Criar conta',
      subtitle: 'Leva menos de um minuto.',
      showBack: true,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Seu nome'),
                  validator: Validators.name,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _password,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.password,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _confirm,
                  label: 'Confirmar senha',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => v != _password.text ? 'As senhas não conferem' : null,
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const _ButtonSpinner() : const Text('Criar conta'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Esqueci a senha

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return _AuthScaffold(
        title: 'Verifique seu e-mail',
        subtitle:
            'Se houver uma conta para ${_email.text.trim()}, você receberá um link para criar uma nova senha. '
            'Abra o link neste aparelho.',
        showBack: true,
        children: [FilledButton(onPressed: () => context.pop(), child: const Text('Voltar ao login'))],
      );
    }
    return _AuthScaffold(
      title: 'Recuperar senha',
      subtitle: 'Enviaremos um link para redefinir sua senha.',
      showBack: true,
      children: [
        Form(
          key: _form,
          child: TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'E-mail'),
            validator: Validators.email,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const _ButtonSpinner() : const Text('Enviar link'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Nova senha (via link)

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      AppFeedback.success(context, 'Senha alterada.');
      ref.read(passwordRecoveryProvider.notifier).set(false);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Nova senha',
      subtitle: 'Escolha uma senha com pelo menos 8 caracteres.',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              _PasswordField(
                controller: _password,
                label: 'Nova senha',
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _confirm,
                label: 'Confirmar nova senha',
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => v != _password.text ? 'As senhas não conferem' : null,
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const _ButtonSpinner() : const Text('Salvar nova senha'),
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white));
}
