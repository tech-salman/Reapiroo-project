import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import 'auth_provider.dart';
import 'services_providers.dart';

/// Stream provider for user wallet transactions
final walletTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);

  final roleAsync = ref.watch(userRoleProvider);
  final isTech = roleAsync.asData?.value == 'tech' || roleAsync.asData?.value == 'technician';

  final paymentService = ref.watch(paymentAndTransactionServiceProvider);
  return paymentService.fetchUserTransactions(user.uid, isTech: isTech);
});

/// Direct wallet balance provider derived from active user profile
final walletBalanceProvider = Provider<double>((ref) {
  final profile = ref.watch(userProfileStreamProvider).asData?.value;
  return profile?.walletBalance ?? 0.0;
});

/// Wallet Controller for balance top-ups and payment operations
class WalletController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> topUpCustomerBalance(double amount, {String paymentMethod = 'card'}) async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null || amount <= 0) return;

    state = const AsyncValue.loading();
    try {
      final dbService = ref.read(databaseServiceProvider);
      await dbService.topUpCustomerBalance(user.uid, amount, paymentMethod);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> recordTransaction({
    required String bookingId,
    required String customerId,
    required String technicianId,
    required double amount,
    double commissionRate = 0.10,
    String paymentMethod = 'cash_on_delivery',
    String paymentStatus = 'paid',
  }) async {
    state = const AsyncValue.loading();
    try {
      final paymentService = ref.read(paymentAndTransactionServiceProvider);
      await paymentService.recordTransaction(
        bookingId: bookingId,
        customerId: customerId,
        technicianId: technicianId,
        amount: amount,
        commissionRate: commissionRate,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final walletControllerProvider = AsyncNotifierProvider<WalletController, void>(() {
  return WalletController();
});
