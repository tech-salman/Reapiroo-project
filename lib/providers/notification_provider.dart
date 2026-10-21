import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import 'auth_provider.dart';
import 'services_providers.dart';

/// Stream provider for real-time notifications of the active user
final notificationsStreamProvider = StreamProvider<List<NotificationItemModel>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);

  final roleAsync = ref.watch(userRoleProvider);
  final isTech = roleAsync.asData?.value == 'tech' || roleAsync.asData?.value == 'technician';

  final dbService = ref.watch(databaseServiceProvider);
  final collection = isTech
      ? dbService.techNotifsCollection(user.uid)
      : dbService.customerNotifsCollection(user.uid);

  return collection.snapshots().map((snap) {
    return snap.docs.map((doc) {
      final d = doc.data();
      return NotificationItemModel(
        id: doc.id,
        title: d['title'] ?? '',
        description: d['body'] ?? d['description'] ?? '',
        time: 'Just now',
        isRead: d['isRead'] ?? false,
        type: d['type'] ?? 'system',
      );
    }).toList();
  });
});

/// Unread notifications count
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsStreamProvider).asData?.value ?? [];
  return notifs.where((n) => !n.isRead).length;
});

/// Notification Controller for marking notifications read
class NotificationController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> markNotificationRead(String id) async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;

    final roleAsync = ref.read(userRoleProvider);
    final isTech = roleAsync.asData?.value == 'tech' || roleAsync.asData?.value == 'technician';

    state = const AsyncValue.loading();
    try {
      final dbService = ref.read(databaseServiceProvider);
      await dbService.markNotificationAsRead(user.uid, id, isTech: isTech);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notificationControllerProvider = AsyncNotifierProvider<NotificationController, void>(() {
  return NotificationController();
});
