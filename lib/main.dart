import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'localization/app_localizations.dart';
import 'providers/localization_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/tech/tech_main_layout.dart';
import 'screens/customer/customer_main_layout.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {}

  try {
    await DatabaseService().purgeLegacyCollections();
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String userRole = prefs.getString('userRole') ?? '';

  runApp(
    ProviderScope(
      child: MyApp(
        initialIsLoggedIn: isLoggedIn,
        initialUserRole: userRole,
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final bool initialIsLoggedIn;
  final String initialUserRole;

  const MyApp({
    super.key,
    required this.initialIsLoggedIn,
    required this.initialUserRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLocale = ref.watch(localizationProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final authState = ref.watch(authStateProvider);
    final roleAsync = ref.watch(userRoleProvider);

    return MaterialApp(
      title: 'Reapiroo',
      debugShowCheckedModeBanner: false,
      locale: activeLocale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('fr'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: appSettings.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        textTheme: GoogleFonts.montserratTextTheme(),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      builder: (context, child) {
        if (kIsWeb) {
          return Container(
            color: const Color(0xFF121212),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        }
        return child ?? const SizedBox.shrink();
      },
      home: authState.when(
        data: (user) {
          if (user == null) {
            return const OnboardingScreen();
          }
          return roleAsync.when(
            data: (role) {
              if (role == 'tech' || role == 'technician') {
                return const TechMainLayout();
              } else {
                return const CustomerMainLayout();
              }
            },
            loading: () => _getInitialScreenFallback(),
            error: (_, __) => _getInitialScreenFallback(),
          );
        },
        loading: () => _getInitialScreenFallback(),
        error: (_, __) => _getInitialScreenFallback(),
      ),
    );
  }

  Widget _getInitialScreenFallback() {
    if (!initialIsLoggedIn) {
      return const OnboardingScreen();
    }
    if (initialUserRole == 'tech' || initialUserRole == 'technician') {
      return const TechMainLayout();
    } else if (initialUserRole == 'customer') {
      return const CustomerMainLayout();
    } else {
      return const OnboardingScreen();
    }
  }
}
