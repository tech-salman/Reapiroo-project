import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String transactionId;
  final String bookingId;
  final String customerId;
  final String technicianId;
  final double amount;
  final double platformFee;
  final double netTechnicianEarnings;
  final String paymentMethod; // 'cash_on_delivery', 'wallet', 'simulated'
  final String paymentStatus; // 'pending', 'paid', 'failed'
  final DateTime? timestamp;

  const TransactionModel({
    required this.transactionId,
    required this.bookingId,
    required this.customerId,
    required this.technicianId,
    required this.amount,
    required this.platformFee,
    required this.netTechnicianEarnings,
    this.paymentMethod = 'cash_on_delivery',
    this.paymentStatus = 'paid',
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'bookingId': bookingId,
      'customerId': customerId,
      'technicianId': technicianId,
      'amount': amount,
      'platformFee': platformFee,
      'netTechnicianEarnings': netTechnicianEarnings,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final double amt = (map['amount'] as num?)?.toDouble() ??
        (map['grossAmount'] as num?)?.toDouble() ??
        0.0;

    final double net = (map['netTechnicianEarnings'] as num?)?.toDouble() ??
        (map['netAmount'] as num?)?.toDouble() ??
        (amt > 0 ? amt * 0.90 : amt);

    return TransactionModel(
      transactionId: docId ?? map['transactionId'] as String? ?? '',
      bookingId: map['bookingId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      technicianId: map['technicianId'] as String? ?? '',
      amount: amt,
      platformFee: (map['platformFee'] as num?)?.toDouble() ?? (amt > 0 ? amt * 0.10 : 0.0),
      netTechnicianEarnings: net,
      paymentMethod: map['paymentMethod'] as String? ?? 'cash_on_delivery',
      paymentStatus: map['paymentStatus'] as String? ?? 'paid',
      timestamp: parseDateTime(map['timestamp'] ?? map['createdAt']),
    );
  }

  TransactionModel copyWith({
    String? transactionId,
    String? bookingId,
    String? customerId,
    String? technicianId,
    double? amount,
    double? platformFee,
    double? netTechnicianEarnings,
    String? paymentMethod,
    String? paymentStatus,
    DateTime? timestamp,
  }) {
    return TransactionModel(
      transactionId: transactionId ?? this.transactionId,
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      technicianId: technicianId ?? this.technicianId,
      amount: amount ?? this.amount,
      platformFee: platformFee ?? this.platformFee,
      netTechnicianEarnings: netTechnicianEarnings ?? this.netTechnicianEarnings,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
