import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationController extends ChangeNotifier {
  static final LocalizationController instance = LocalizationController._internal();

  factory LocalizationController() => instance;

  LocalizationController._internal();

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  bool get isRtl => _locale.languageCode == 'ar';

  TextDirection get textDirection => isRtl ? TextDirection.rtl : TextDirection.ltr;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
    Locale('fr'),
    Locale('es'),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? langCode = prefs.getString('app_language');
    if (langCode != null && ['en', 'ar', 'fr', 'es'].contains(langCode)) {
      _locale = Locale(langCode);
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    if (!['en', 'ar', 'fr', 'es'].contains(languageCode)) return;
    if (_locale.languageCode == languageCode) return;

    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
    notifyListeners();
  }

  String get currentLanguageName {
    switch (_locale.languageCode) {
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
