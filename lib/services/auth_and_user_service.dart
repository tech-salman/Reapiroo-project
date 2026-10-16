import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'database_service.dart';

class AuthAndUserService {
  final FirebaseAuth _auth;
  final DatabaseService _dbService = DatabaseService();

  AuthAndUserService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  }) : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;

  /// Fetches the user document from Firestore to determine user role ('customer' or 'tech').
  Future<String> getCurrentUserRole() async {
    final uid = currentUid;
    final user = _auth.currentUser;
    final email = user?.email;
    final phone = user?.phoneNumber;

    if (uid != null) {
      try {
        final profileDoc = await _dbService.getUserProfile(uid);
        if (profileDoc.exists && profileDoc.data() != null) {
          return profileDoc.data()!['role'] as String? ?? 'customer';
        }
      } catch (_) {}
    }

    if (email != null && email.isNotEmpty) {
      try {
        final data = await _dbService.checkUserExistsByEmail(email);
        if (data != null) {
          return data['role'] as String? ?? 'customer';
        }
      } catch (_) {}
    }

    if (phone != null && phone.isNotEmpty) {
      try {
        final data = await _dbService.checkUserExistsByPhone(phone);
        if (data != null) {
          return data['role'] as String? ?? 'customer';
        }
      } catch (_) {}
    }

    return 'customer';
  }

  /// Updates profile metadata for the authenticated user.
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final uid = currentUid;
    if (uid == null) {
      throw Exception('User must be logged in to update profile.');
    }

    final role = data['role'] as String? ?? await getCurrentUserRole();

    if (role == 'tech') {
      await _dbService.updateTechProfile(uid, data);
    } else {
      await _dbService.updateCustomerProfile(uid, data);
    }
  }

  /// Creates or replaces full user profile document.
  Future<void> saveUserProfile(UserModel user) async {
    await _dbService.saveUserProfile(
      uid: user.uid,
      role: user.role,
      name: user.fullName,
      email: user.email,
      phoneNumber: user.phoneNumber,
      avatarUrl: user.profilePicUrl,
      isVerified: true,
    );
  }

  /// Fetches public profile metadata for a technician by [techId].
  Future<UserModel?> getTechnicianProfile(String techId) async {
    try {
      final doc = await _dbService.getTechProfile(techId);
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, docId: doc.id);
      }
    } catch (_) {}
    return null;
  }

  /// Streams real-time updates for the current user's profile.
  Stream<UserModel?> streamCurrentUserProfile() {
    final uid = currentUid;
    if (uid == null) return Stream.value(null);

    return _dbService.streamUserProfile(uid).map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserModel.fromMap(snapshot.data()!, docId: snapshot.id);
    });
  }
}
