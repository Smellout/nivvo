import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/services/core_providers.dart';

@immutable
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.remindersEnabled,
    required this.hideAmountsInReminders,
    required this.lastRateHundredths,
    required this.lastTermDays,
  });

  final ThemeMode themeMode;
  final bool remindersEnabled;
  final bool hideAmountsInReminders;

  /// Pré-preenchimento da nova operação (acelera o cadastro).
  final int? lastRateHundredths;
  final int? lastTermDays;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? remindersEnabled,
    bool? hideAmountsInReminders,
    int? lastRateHundredths,
    int? lastTermDays,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      hideAmountsInReminders: hideAmountsInReminders ?? this.hideAmountsInReminders,
      lastRateHundredths: lastRateHundredths ?? this.lastRateHundredths,
      lastTermDays: lastTermDays ?? this.lastTermDays,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  static const _kTheme = 'settings.theme';
  static const _kReminders = 'settings.reminders';
  static const _kHideAmounts = 'settings.hideAmounts';
  static const _kLastRate = 'settings.lastRate';
  static const _kLastTerm = 'settings.lastTerm';

  @override
  AppSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[p.getString(_kTheme)] ?? ThemeMode.dark,
      remindersEnabled: p.getBool(_kReminders) ?? true,
      hideAmountsInReminders: p.getBool(_kHideAmounts) ?? false,
      lastRateHundredths: p.getInt(_kLastRate),
      lastTermDays: p.getInt(_kLastTerm),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString(_kTheme, mode.name);
  }

  Future<void> setRemindersEnabled(bool value) async {
    state = state.copyWith(remindersEnabled: value);
    await ref.read(sharedPreferencesProvider).setBool(_kReminders, value);
  }

  Future<void> setHideAmounts(bool value) async {
    state = state.copyWith(hideAmountsInReminders: value);
    await ref.read(sharedPreferencesProvider).setBool(_kHideAmounts, value);
  }

  Future<void> rememberLoanDefaults({required int rateHundredths, required int termDays}) async {
    state = state.copyWith(lastRateHundredths: rateHundredths, lastTermDays: termDays);
    final p = ref.read(sharedPreferencesProvider);
    await p.setInt(_kLastRate, rateHundredths);
    await p.setInt(_kLastTerm, termDays);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
