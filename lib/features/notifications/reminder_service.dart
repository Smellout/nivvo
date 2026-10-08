import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/dates.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/services/core_providers.dart';
import '../settings/settings_controller.dart';
import 'reminder_planner.dart';

/// Agenda lembretes locais de vencimento. A cada sincronização o conjunto inteiro
/// é refeito, então operações quitadas/canceladas deixam de notificar automaticamente.
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Id da operação tocada na notificação (o app navega até ela).
  final ValueNotifier<String?> openedLoanId = ValueNotifier(null);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'due_reminders',
      'Lembretes de vencimento',
      channelDescription: 'Avisos de operações próximas do vencimento ou vencidas',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_nivvo',
      color: Color(0xFF4F7CFF),
      category: AndroidNotificationCategory.reminder,
    ),
  );

  Future<void> init({String timezone = 'America/Sao_Paulo'}) async {
    if (_ready || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(timezone));
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_nivvo')),
      onDidReceiveNotificationResponse: (r) => openedLoanId.value = r.payload,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      openedLoanId.value = launch!.notificationResponse?.payload;
    }
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> areEnabled() async => _ready && (await _android?.areNotificationsEnabled() ?? false);

  /// Pede a permissão POST_NOTIFICATIONS (Android 13+).
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }

  Future<int> reschedule(List<PlannedReminder> reminders) async {
    if (!_ready) return 0;
    await _plugin.cancelAll();
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: r.loanId,
        scheduledDate: tz.TZDateTime(tz.local, r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute),
        notificationDetails: _details,
        // Inexato: não exige a permissão restrita de alarme exato (Android 14+).
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    return reminders.length;
  }
}

/// Mantém os lembretes sincronizados com os dados: recalcula quando qualquer
/// escrita acontece (dataRevision) ou quando as preferências mudam.
final reminderSyncProvider = FutureProvider<int>((ref) async {
  ref.watch(dataRevisionProvider);
  final userId = ref.watch(currentUserIdProvider);
  final settings = ref.watch(settingsProvider);
  final service = ReminderService.instance;

  if (userId == null || !settings.remindersEnabled) {
    await service.cancelAll();
    return 0;
  }

  final today = Dates.today();
  final loans = await ref
      .read(loansRepositoryProvider)
      .activeDueBetween(Dates.addDays(today, -2), Dates.addDays(today, ReminderPlanner.lookaheadDays));

  final planned = ReminderPlanner.plan(
    [
      for (final l in loans)
        ReminderLoan(loanId: l.id, clientName: l.clientName, remainingCents: l.remainingCents, dueDate: l.dueDate),
    ],
    now: DateTime.now(),
    hideAmounts: settings.hideAmountsInReminders,
  );
  return service.reschedule(planned);
});
