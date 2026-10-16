import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/services/auth_service.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/screens/role_selection_screen.dart';
import 'package:reapiroo/screens/tech/tech_main_layout.dart';
import 'package:reapiroo/screens/customer/customer_main_layout.dart';

class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();

  void _showGoogleConsentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.g_mobiledata, size: 36, color: Colors.blue),
            SizedBox(width: 8),
            Text('Google Sign-In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reapiroo would like to access the following information from your Google Account:',
              style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 18, color: Colors.black54),
                      SizedBox(width: 10),
                      Text('Profile Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 18, color: Colors.black54),
                      SizedBox(width: 10),
                      Text('Email Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.image_outlined, size: 18, color: Colors.black54),
                      SizedBox(width: 10),
                      Text('Profile Picture', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This information is securely shared with the backend to personalize your experience and secure your account.',
              style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(context);
              _handleGoogleSignIn();
            },
            child: const Text('Allow & Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCred = await _authService.signInWithGoogle(
        onFailed: (err) {
          if (mounted) {
            setState(() {
              _errorMessage = err;
              _isLoading = false;
            });
          }
        },
      );

      if (!mounted) return;
      final user = userCred?.user;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final email = user.email ?? '';
      final displayName = user.displayName ?? '';
      final photoUrl = user.photoURL ?? '';

      final navigator = Navigator.of(context);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('email', email);
      if (displayName.isNotEmpty) {
        await prefs.setString('google_display_name', displayName);
      }
      if (photoUrl.isNotEmpty) {
        await prefs.setString('google_photo_url', photoUrl);
        await prefs.setString('profile_photo_url', photoUrl);
      }

      // Check if user exists in Firestore by UID or email safely
      Map<String, dynamic>? userData;
      try {
        final profileDoc = await _dbService.getUserProfile(user.uid);
        if (profileDoc.exists && profileDoc.data() != null) {
          userData = profileDoc.data();
        } else {
          userData = await _dbService.checkUserExistsByEmail(email);
        }
      } catch (_) {
        userData = null;
      }

      if (userData != null && photoUrl.isNotEmpty) {
        final phoneKey = userData['phoneKey'] as String?;
        final role = userData['role'] as String? ?? 'customer';
        if (phoneKey != null && phoneKey.isNotEmpty) {
          if (role == 'tech') {
            await _dbService.updateTechProfile(phoneKey, {'avatarUrl': photoUrl});
          } else {
            await _dbService.updateCustomerProfile(phoneKey, {'avatarUrl': photoUrl});
          }
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (userData == null) {
        // User does not exist -> Role Selection Screen for signup
        navigator.pushReplacement(
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        );
      } else {
        // User exists -> Route based on role
        final role = userData['role'] as String? ?? 'customer';
        final name = userData['name'] as String? ?? displayName;

        await prefs.setString('userRole', role);
        await prefs.setString('firstName', name);

        if (!mounted) return;
        if (role == 'tech') {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const TechMainLayout()),
            (route) => false,
          );
        } else {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const CustomerMainLayout()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/onb_welcome.png',
                width: MediaQuery.of(context).size.width * 0.6,
              ),
              const SizedBox(height: 40),
              const Text(
                'Login or Signup',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign in with Google to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 50),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],

              // Google Sign-In Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showGoogleConsentDialog,
                  icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.black),
                  label: const Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              if (_isLoading) ...[
                const SizedBox(height: 40),
                const CircularProgressIndicator(color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
