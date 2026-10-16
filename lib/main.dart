import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:reapiroo/screens/onboarding_screen.dart';
import 'package:reapiroo/screens/tech/tech_main_layout.dart';
import 'package:reapiroo/screens/customer/customer_main_layout.dart';

import 'package:reapiroo/services/database_service.dart';

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

  runApp(MyApp(isLoggedIn: isLoggedIn, userRole: userRole));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String userRole;

  const MyApp({super.key, required this.isLoggedIn, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reapiroo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.montserratTextTheme(),
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
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {
    if (!isLoggedIn) {
      return const OnboardingScreen();
    }

    if (userRole == 'tech') {
      return const TechMainLayout();
    } else if (userRole == 'customer') {
      return const CustomerMainLayout();
    } else {
      return const OnboardingScreen();
    }
  }
}