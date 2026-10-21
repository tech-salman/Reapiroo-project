import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsState {
  final bool darkModeEnabled;
  final bool pushNotificationsEnabled;

  const AppSettingsState({
    this.darkModeEnabled = false,
    this.pushNotificationsEnabled = true,
  });

  AppSettingsState copyWith({
    bool? darkModeEnabled,
    bool? pushNotificationsEnabled,
  }) {
    return AppSettingsState(
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  @override
  AppSettingsState build() {
    _loadPreferences();
    return const AppSettingsState();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final darkMode = prefs.getBool('dark_mode') ?? false;
    final pushNotifs = prefs.getBool('push_notifications') ?? true;
    state = AppSettingsState(
      darkModeEnabled: darkMode,
      pushNotificationsEnabled: pushNotifs,
    );
  }

  Future<void> setDarkMode(bool val) async {
    state = state.copyWith(darkModeEnabled: val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', val);
  }

  Future<void> setPushNotifications(bool val) async {
    state = state.copyWith(pushNotificationsEnabled: val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', val);
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettingsState>(() {
  return AppSettingsNotifier();
});
