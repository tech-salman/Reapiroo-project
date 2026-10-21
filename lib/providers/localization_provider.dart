import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _loadSavedLanguage();
    return const Locale('en');
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? langCode = prefs.getString('app_language');
    if (langCode != null && ['en', 'ar', 'fr', 'es'].contains(langCode)) {
      state = Locale(langCode);
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    if (!['en', 'ar', 'fr', 'es'].contains(languageCode)) return;
    if (state.languageCode == languageCode) return;

    state = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
  }

  String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'ar':
        return 'العربية (Arabic)';
      case 'fr':
        return 'Français (French)';
      case 'es':
        return 'Español (Spanish)';
      case 'en':
      default:
        return 'English';
    }
  }
}

final localizationProvider = NotifierProvider<LocalizationNotifier, Locale>(() {
  return LocalizationNotifier();
});

final isRtlProvider = Provider<bool>((ref) {
  final locale = ref.watch(localizationProvider);
  return locale.languageCode == 'ar';
});

final textDirectionProvider = Provider<TextDirection>((ref) {
  final isRtl = ref.watch(isRtlProvider);
  return isRtl ? TextDirection.rtl : TextDirection.ltr;
});
