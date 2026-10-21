import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/auth_and_user_service.dart';
import '../services/booking_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../services/payment_and_transaction_service.dart';
import '../services/permission_service.dart';

/// Service level providers for dependency injection across Riverpod architecture.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authAndUserServiceProvider = Provider<AuthAndUserService>((ref) {
  return AuthAndUserService();
});

final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService();
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final paymentAndTransactionServiceProvider = Provider<PaymentAndTransactionService>((ref) {
  return PaymentAndTransactionService();
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});
