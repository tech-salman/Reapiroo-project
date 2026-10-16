import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  ConfirmationResult? _confirmationResult;

  // Stream to listen to real-time auth state changes (logged in / logged out)
  Stream<User?> get userStream => _auth.authStateChanges();

  // Get current logged-in user details
  User? get currentUser => _auth.currentUser;

  // 1. Send OTP to the technician's phone number
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String error) onFailed,
    required Function() onCodeSent,
  }) async {
    try {
      if (kIsWeb) {
        _confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);
        onCodeSent();
        return;
      }
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android devices may automatically resolve and sign in the user
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onFailed(e.message ?? "Verification failed.");
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      onFailed(e.toString());
    }
  }

  // 2. Submit the OTP code entered by the technician to sign in
  Future<UserCredential?> verifyOtp({
    required String smsCode,
    String? verificationId,
    required Function(String error) onFailed,
  }) async {
    if (kIsWeb && _confirmationResult != null) {
      try {
        return await _confirmationResult!.confirm(smsCode);
      } on FirebaseAuthException catch (e) {
        onFailed(e.message ?? "Invalid code entered.");
        return null;
      } catch (e) {
        onFailed(e.toString());
        return null;
      }
    }

    final vId = verificationId ?? _verificationId;
    if (vId == null) {
      onFailed("Verification ID is missing. Send OTP first.");
      return null;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: vId,
        smsCode: smsCode,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      onFailed(e.message ?? "Invalid code entered.");
      return null;
    } catch (e) {
      onFailed(e.toString());
      return null;
    }
  }

  // 3. Log out the user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 6. Sign in with Google
  Future<UserCredential?> signInWithGoogle({
    required Function(String error) onFailed,
  }) async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(googleProvider);
      }

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        onFailed("Google sign in cancelled.");
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      onFailed(e.message ?? "Google sign-in failed.");
      return null;
    } catch (e) {
      onFailed(e.toString());
      return null;
    }
  }
}
