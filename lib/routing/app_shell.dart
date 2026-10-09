import 'dart:ui' show ImageFilter;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/notifications/reminder_service.dart';
import '../shared/models/client.dart';
import '../theme/app_colors.dart';
import '../shared/widgets/common.dart';
import '../shared/widgets/welcome_overlay.dart';

/// Estrutura principal: navegação inferior + botão "Nova operação" sempre à mão.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _reminders = ReminderService.instance;

  /// Saudação animada exibida uma vez a cada entrada no app (abertura ou login).
  bool _showWelcome = true;

  @override
  void initState() {
    super.initState();
    _reminders.openedLoanId.addListener(_openFromNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotification());
  }

  @override
  void dispose() {
    _reminders.openedLoanId.removeListener(_openFromNotification);
    super.dispose();
  }

  void _openFromNotification() {
    final id = _reminders.openedLoanId.value;
    if (id == null || !mounted) return;
    _reminders.openedLoanId.value = null;
    context.push('/loan/$id');
  }

  void _onTab(int index) {
    widget.shell.goBranch(index, initialLocation: index == widget.shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Mantém os lembretes locais sincronizados com os dados.
    ref.watch(reminderSyncProvider);
    final index = widget.shell.currentIndex;

    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shell = Scaffold(
      backgroundColor: c.background,
      // O conteúdo passa por trás da barra de navegação de vidro.
      extendBody: true,
      body: Builder(
        builder: (context) => Stack(
          children: [
            widget.shell,
            const Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false, child: OfflineBanner())),
          ],
        ),
      ),
      // No Início a ação "Nova" já está em destaque; nas listas, o botão flutuante.
      floatingActionButton: switch (index) {
        1 => FloatingActionButton(
          heroTag: 'new-loan',
          tooltip: 'Nova operação',
          onPressed: () => context.push('/new-loan'),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
        2 => FloatingActionButton.extended(
          heroTag: 'new-client',
          onPressed: () async {
            final created = await context.push<Client>('/client-form');
            if (created != null && context.mounted) context.push('/client/${created.id}');
          },
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Novo cliente'),
        ),
        _ => null,
      },
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? c.background.withValues(alpha: 0.72) : Colors.white.withValues(alpha: 0.78),
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: _onTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_vert_rounded),
                  selectedIcon: Icon(Icons.swap_vert_rounded),
                  label: 'Operações',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline_rounded),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: 'Clientes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_rounded),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Relatórios',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_rounded),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: 'Ajustes',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        shell,
        if (_showWelcome) Positioned.fill(child: WelcomeOverlay(onDone: () => setState(() => _showWelcome = false))),
      ],
    );
  }
}
