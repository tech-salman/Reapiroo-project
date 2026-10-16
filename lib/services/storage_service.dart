import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const int maxBytesLimit = 10 * 1024; // 10 KB target limit for profile pictures

  /// Automatically compresses image bytes down to ~10KB (max 10240 bytes)
  Future<Uint8List> compressImageTo10KB(Uint8List originalBytes) async {
    try {
      Uint8List currentBytes = originalBytes;
      int targetDimension = 120; // 120x120 pixels optimal for profile avatars

      while (targetDimension >= 40) {
        final codec = await ui.instantiateImageCodec(
          currentBytes,
          targetWidth: targetDimension,
          targetHeight: targetDimension,
        );
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          final pngBytes = data.buffer.asUint8List();
          if (pngBytes.length <= 10 * 1024 || targetDimension <= 40) {
            return pngBytes;
          }
          currentBytes = pngBytes;
        }
        targetDimension -= 20;
      }
      return currentBytes;
    } catch (_) {
      return originalBytes;
    }
  }

  /// Encodes image bytes into a Base64 Data URI string.
  Future<String> compressAndEncodeBase64Bytes(Uint8List originalBytes) async {
    try {
      final compressedBytes = await compressImageTo10KB(originalBytes);
      final base64Str = base64Encode(compressedBytes);
      return 'data:image/png;base64,$base64Str';
    } catch (_) {
      return 'data:image/jpeg;base64,${base64Encode(originalBytes)}';
    }
  }

  /// Compresses a local image File or XFile to Base64 Data URI.
  Future<String?> compressAndEncodeBase64(dynamic fileOrXFile) async {
    try {
      Uint8List bytes;
      if (fileOrXFile is XFile) {
        bytes = await fileOrXFile.readAsBytes();
      } else if (!kIsWeb && fileOrXFile is File) {
        bytes = await fileOrXFile.readAsBytes();
      } else {
        return null;
      }
      return await compressAndEncodeBase64Bytes(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Uploads Profile Picture from XFile after automatically compressing it to ~10KB.
  Future<String> uploadProfileImageXFile({
    required String uid,
    required XFile xfile,
  }) async {
    final cleanUid = uid.replaceAll(RegExp(r'[^\w.-]'), '_');
    final originalBytes = await xfile.readAsBytes();
    
    // Automatically compress to ~10KB before upload
    final compressedBytes = await compressImageTo10KB(originalBytes);

    try {
      final ref = _storage.ref('user_avatars/$cleanUid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putData(compressedBytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      if (downloadUrl.isNotEmpty) {
        return downloadUrl;
      }
    } catch (e) {
      debugPrint('Firebase Storage upload notice ($e). Using compressed Base64 Data URI.');
    }

    final base64Result = await compressAndEncodeBase64Bytes(compressedBytes);
    return base64Result ?? 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';
  }

  /// Uploads Profile Picture from File (Mobile/Desktop) after automatically compressing it to ~10KB.
  Future<String> uploadProfilePicture({
    required String uid,
    required File file,
  }) async {
    final xfile = XFile(file.path);
    return uploadProfileImageXFile(uid: uid, xfile: xfile);
  }

  /// Uploads Technician Verification Document from XFile (Web and Mobile).
  Future<String?> uploadVerificationDocumentXFile({
    required String uid,
    required XFile xfile,
    required String fileName,
  }) async {
    final cleanUid = uid.replaceAll(RegExp(r'[^\w.-]'), '_');
    final bytes = await xfile.readAsBytes();

    try {
      final ref = _storage.ref('verification_docs/$cleanUid/${fileName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      if (downloadUrl.isNotEmpty) {
        return downloadUrl;
      }
    } catch (e) {
      debugPrint('Firebase Storage upload notice ($e) for verification doc. Using Base64 Data URI.');
    }

    return await compressAndEncodeBase64Bytes(bytes);
  }

  /// Uploads Technician Verification Document -> Returns Base64 Data URI (<50KB) or Storage URL
  Future<String?> uploadVerificationDocument({
    required String uid,
    required File file,
    required String fileName,
  }) async {
    if (kIsWeb) {
      final xfile = XFile(file.path);
      return uploadVerificationDocumentXFile(uid: uid, xfile: xfile, fileName: fileName);
    }
    return await compressAndEncodeBase64(file);
  }

  /// Helper to convert a stored Base64 string, local File path, or HTTP/HTTPS/Blob URL into a Flutter ImageProvider.
  static ImageProvider getImageProvider(String? urlOrPath, {String? defaultUrl}) {
    final fallback = defaultUrl ?? '';
    if (urlOrPath == null || urlOrPath.trim().isEmpty) {
      return NetworkImage(fallback.isNotEmpty ? fallback : 'https://via.placeholder.com/150');
    }
    final clean = urlOrPath.trim();

    // 0. Asset Image Path
    if (clean.startsWith('assets/')) {
      return AssetImage(clean);
    }

    // 1. Base64 Data URI or raw Base64 string
    if (clean.startsWith('data:image') || clean.length > 300) {
      try {
        final base64Clean = clean.contains(',') ? clean.split(',').last : clean;
        final bytes = base64Decode(base64Clean);
        return MemoryImage(bytes);
      } catch (_) {}
    }

    // 2. Network URL or Web Blob URL
    if (clean.startsWith('http://') || clean.startsWith('https://') || clean.startsWith('blob:')) {
      return NetworkImage(clean);
    }

    // 3. Local File Path (if present on mobile/desktop device)
    if (!kIsWeb) {
      try {
        final file = File(clean);
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (_) {}
    }

    return NetworkImage(fallback);
  }
}
