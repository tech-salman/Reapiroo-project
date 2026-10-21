import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/user_profile.dart';
import 'services_providers.dart';

/// Stream of FirebaseAuth user state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.userStream;
});

/// Current authenticated User or null
final currentFirebaseUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).asData?.value;
});

/// Stream of UserProfile for the logged-in user
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value(null);

  final dbService = ref.watch(databaseServiceProvider);
  return dbService.streamUserProfile(user.uid).map((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) return null;
    final data = snapshot.data()!;
    final roleStr = data['role'] as String? ?? 'customer';
    final isTech = roleStr == 'technician' || roleStr == 'tech';

    return UserProfile(
      id: snapshot.id,
      firstName: data['fullName'] ?? data['name'] ?? '',
      lastName: '',
      email: data['email'] ?? '',
      phone: data['phoneNumber'] ?? '',
      role: isTech ? UserRole.tech : UserRole.customer,
      bio: data['bio'] ?? '',
      avatarUrl: data['avatarUrl'] ?? data['profilePictureUrl'] ?? '',
      walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble() ?? 0.0,
      experienceYears: (data['experienceYears'] as num?)?.toInt() ?? 0,
      selectedServices: (data['selectedServices'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  });
});

/// Current user role ('customer' or 'tech')
final userRoleProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return 'customer';
  final authAndUserService = ref.watch(authAndUserServiceProvider);
  return await authAndUserService.getCurrentUserRole();
});

/// Auth Controller for managing login, sign up, OTP, and logout operations
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // initial state is data(null)
  }

  Future<UserCredential?> signInWithGoogle({
    required Function(String error) onFailed,
  }) async {
    state = const AsyncValue.loading();
    UserCredential? credential;
    try {
      final authService = ref.read(authServiceProvider);
      credential = await authService.signInWithGoogle(onFailed: onFailed);
      if (credential?.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    return credential;
  }

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String error) onFailed,
    required Function() onCodeSent,
  }) async {
    state = const AsyncValue.loading();
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendOtp(
        phoneNumber: phoneNumber,
        onFailed: onFailed,
        onCodeSent: onCodeSent,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<UserCredential?> verifyOtp({
    required String smsCode,
    String? verificationId,
    required Function(String error) onFailed,
  }) async {
    state = const AsyncValue.loading();
    UserCredential? credential;
    try {
      final authService = ref.read(authServiceProvider);
      credential = await authService.verifyOtp(
        smsCode: smsCode,
        verificationId: verificationId,
        onFailed: onFailed,
      );
      if (credential?.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    return credential;
  }

  Future<void> saveUserProfile(UserModel user) async {
    state = const AsyncValue.loading();
    try {
      final authAndUserService = ref.read(authAndUserServiceProvider);
      await authAndUserService.saveUserProfile(user);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', user.role);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final authAndUserService = ref.read(authAndUserServiceProvider);
      await authAndUserService.updateUserProfile(data);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userRole');

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});
