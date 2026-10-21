import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';

class PaymentAndTransactionService {
  final DatabaseService _dbService = DatabaseService();

  PaymentAndTransactionService();

  String _generate9DigitId() {
    return _dbService.generate9DigitId();
  }

  Future<TransactionModel> recordTransaction({
    required String bookingId,
    required String customerId,
    required String technicianId,
    required double amount,
    double commissionRate = 0.10,
    String paymentMethod = 'cash_on_delivery',
    String paymentStatus = 'paid',
    String bidId = '',
  }) async {
    final paymentId = _generate9DigitId();
    final platformFee = amount * commissionRate;
    final netTechnicianEarnings = amount - platformFee;
    final effectiveBidId = bidId.isNotEmpty ? bidId : _generate9DigitId();

    final transaction = TransactionModel(
      transactionId: paymentId,
      bookingId: bookingId,
      customerId: customerId,
      technicianId: technicianId,
      amount: amount,
      platformFee: platformFee,
      netTechnicianEarnings: netTechnicianEarnings,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
    );

    final paymentData = {
      ...transaction.toMap(),
      'paymentId': paymentId,
      'bidId': effectiveBidId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (customerId.isNotEmpty) {
      await _dbService.customerTransactionsCollection(customerId).doc(paymentId).set(paymentData);
    }
    if (technicianId.isNotEmpty) {
      await _dbService.techTransactionsCollection(technicianId).doc(paymentId).set(paymentData);
    }

    return transaction;
  }

  Stream<List<TransactionModel>> fetchUserTransactions(String userId, {bool isTech = false}) {
    final collection = isTech 
        ? _dbService.techTransactionsCollection(userId) 
        : _dbService.customerTransactionsCollection(userId);

    return collection.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), docId: doc.id))
          .toList();

      list.sort((a, b) {
        if (a.timestamp == null) return 1;
        if (b.timestamp == null) return -1;
        return b.timestamp!.compareTo(a.timestamp!);
      });
      return list;
    });
  }
}
