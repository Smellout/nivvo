import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/notifications/reminder_service.dart';
import '../shared/widgets/common.dart';

/// Estrutura principal: navegação inferior + botão "Nova operação" sempre à mão.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _reminders = ReminderService.instance;

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

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: OfflineBanner()),
          Expanded(
            child: MediaQuery.removePadding(context: context, removeTop: true, child: widget.shell),
          ),
        ],
      ),
      floatingActionButton: index == 4
          ? null
          : FloatingActionButton(
              heroTag: 'new-loan',
              tooltip: 'Nova operação',
              onPressed: () => context.push('/new-loan'),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _onTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_vert_rounded),
            selectedIcon: Icon(Icons.swap_vert_circle_rounded),
            label: 'Operações',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Relatórios',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
