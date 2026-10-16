import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  /// Check if location permission is granted.
  static Future<bool> checkLocationPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Request location permission.
  static Future<bool> requestLocationPermission(
    BuildContext context, {
    String? reason,
  }) async {
    if (kIsWeb) return true;
    final status = await Permission.location.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.location.request();
    if (result.isGranted) {
      return true;
    }

    if (context.mounted) {
      await showPermissionDeniedDialog(
        context,
        title: 'Location Permission Required',
        message: reason ??
            'Reapiroo requires explicit access to your Location to match you with nearby technicians and accurately pin your service address.',
        isPermanentlyDenied: result.isPermanentlyDenied || result.isRestricted,
      );
    }
    return false;
  }

  /// Check if camera permission is granted.
  static Future<bool> checkCameraPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Request camera permission.
  static Future<bool> requestCameraPermission(
    BuildContext context, {
    String? reason,
  }) async {
    if (kIsWeb) return true;
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.camera.request();
    if (result.isGranted) {
      return true;
    }

    if (context.mounted) {
      await showPermissionDeniedDialog(
        context,
        title: 'Camera Access Required',
        message: reason ??
            'Reapiroo requires access to your Camera to allow taking photos of service issues, spare parts, and invoices.',
        isPermanentlyDenied: result.isPermanentlyDenied || result.isRestricted,
      );
    }
    return false;
  }

  /// Check if notification permission is granted.
  static Future<bool> checkNotificationPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Request notification permission.
  static Future<bool> requestNotificationPermission(
    BuildContext context, {
    String? reason,
  }) async {
    if (kIsWeb) return true;
    final status = await Permission.notification.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.notification.request();
    if (result.isGranted) {
      return true;
    }

    if (context.mounted) {
      await showPermissionDeniedDialog(
        context,
        title: 'Notification Permission Required',
        message: reason ??
            'Reapiroo requires Notification permissions to alert you about real-time bids, booking updates, and chat messages.',
        isPermanentlyDenied: result.isPermanentlyDenied || result.isRestricted,
      );
    }
    return false;
  }

  /// Check if media/photos permission is granted.
  static Future<bool> checkMediaPermission() async {
    if (kIsWeb) return true;
    if (!kIsWeb && Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }

    final photosStatus = await Permission.photos.status;
    final storageStatus = await Permission.storage.status;
    return photosStatus.isGranted ||
        photosStatus.isLimited ||
        storageStatus.isGranted;
  }

  /// Request media/photos access.
  static Future<bool> requestMediaPermission(
    BuildContext context, {
    String? reason,
  }) async {
    if (kIsWeb) return true;
    if (await checkMediaPermission()) {
      return true;
    }

    Map<Permission, PermissionStatus> statuses;
    if (!kIsWeb && Platform.isIOS) {
      statuses = await [
        Permission.photos,
      ].request();
    } else {
      statuses = await [
        Permission.photos,
        Permission.storage,
      ].request();
    }

    final isGranted = await checkMediaPermission();
    if (isGranted) {
      return true;
    }

    final bool isPermanentlyDenied =
        (statuses[Permission.photos]?.isPermanentlyDenied ?? false) ||
            (statuses[Permission.storage]?.isPermanentlyDenied ?? false) ||
            (statuses[Permission.photos]?.isRestricted ?? false);

    if (context.mounted) {
      await showPermissionDeniedDialog(
        context,
        title: 'Media & Photo Access Required',
        message: reason ??
            'Reapiroo requires access to your Photo Library & Storage to allow uploading task photos, spare part receipts, and documents.',
        isPermanentlyDenied: isPermanentlyDenied,
      );
    }
    return false;
  }

  /// Check if microphone permission is granted.
  static Future<bool> checkMicrophonePermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission.
  static Future<bool> requestMicrophonePermission(
    BuildContext context, {
    String? reason,
  }) async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.microphone.request();
    if (result.isGranted) {
      return true;
    }

    if (context.mounted) {
      await showPermissionDeniedDialog(
        context,
        title: 'Microphone Access Required',
        message: reason ??
            'Reapiroo requires access to your Microphone to record voice notes for service technicians.',
        isPermanentlyDenied: result.isPermanentlyDenied || result.isRestricted,
      );
    }
    return false;
  }

  /// Check if all required app permissions are granted.
  static Future<bool> checkAllPermissions() async {
    if (kIsWeb) return true;
    final locGranted = await checkLocationPermission();
    final mediaGranted = await checkMediaPermission();
    final micGranted = await checkMicrophonePermission();
    final camGranted = await checkCameraPermission();
    return locGranted && mediaGranted && micGranted && camGranted;
  }

  /// Request all core permissions in sequence/batch.
  static Future<bool> requestAllPermissions(BuildContext context) async {
    if (kIsWeb) return true;
    if (await checkAllPermissions()) {
      return true;
    }

    final Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.photos,
      Permission.camera,
      Permission.storage,
      Permission.microphone,
      Permission.notification,
    ].request();

    final allGranted = await checkAllPermissions();
    if (allGranted) {
      return true;
    }

    final bool isPermanentlyDenied =
        (statuses[Permission.location]?.isPermanentlyDenied ?? false) ||
            (statuses[Permission.photos]?.isPermanentlyDenied ?? false) ||
            (statuses[Permission.camera]?.isPermanentlyDenied ?? false) ||
            (statuses[Permission.storage]?.isPermanentlyDenied ?? false) ||
            (statuses[Permission.microphone]?.isPermanentlyDenied ?? false);

    if (context.mounted) {
      await showPermissionDeniedDialog(
        context,
        title: 'Device Permissions Required',
        message:
            'Reapiroo requires explicit access to your Device Location (for technician matching), Camera & Media Library (for task pictures), and Microphone (for voice notes).\n\nPlease grant these permissions to proceed with service requests.',
        isPermanentlyDenied: isPermanentlyDenied,
      );
    }
    return false;
  }

  /// Show a standardized dialog informing the user about denied permissions.
  static Future<void> showPermissionDeniedDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool isPermanentlyDenied = false,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.black87),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isPermanentlyDenied
              ? '$message\n\nPermissions were permanently denied. Please enable them manually from your device settings.'
              : message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!kIsWeb) {
                openAppSettings();
              }
            },
            child: Text(
              isPermanentlyDenied ? 'Open Settings' : 'App Settings',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool> openSettings() async {
    if (kIsWeb) return true;
    return await openAppSettings();
  }
}
