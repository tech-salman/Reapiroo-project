import 'package:cloud_firestore/cloud_firestore.dart';

class BidModel {
  final String bidId;
  final String bookingId;
  final String technicianId;
  final String technicianName;
  final double technicianRating;
  final double proposedPrice;
  final String note;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime? createdAt;

  const BidModel({
    this.bidId = '',
    this.bookingId = '',
    required this.technicianId,
    required this.technicianName,
    this.technicianRating = 0.0,
    required this.proposedPrice,
    this.note = '',
    this.status = 'pending',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'bidId': bidId,
      'bookingId': bookingId,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'technicianRating': technicianRating,
      'proposedPrice': proposedPrice,
      'note': note,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory BidModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return BidModel(
      bidId: docId ?? map['bidId'] as String? ?? map['offerId'] as String? ?? '',
      bookingId: map['bookingId'] as String? ?? map['requestId'] as String? ?? '',
      technicianId: map['technicianId'] as String? ?? map['techId'] as String? ?? '',
      technicianName: map['technicianName'] as String? ?? map['techName'] as String? ?? '',
      technicianRating: (map['technicianRating'] as num?)?.toDouble() ?? (map['techRating'] as num?)?.toDouble() ?? 0.0,
      proposedPrice: (map['proposedPrice'] as num?)?.toDouble() ?? (map['price'] as num?)?.toDouble() ?? (map['amount'] as num?)?.toDouble() ?? (map['bidAmount'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] as String? ?? map['notes'] as String? ?? map['proposalNote'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt: parseDateTime(map['createdAt'] ?? map['updatedAt']),
    );
  }

  BidModel copyWith({
    String? bidId,
    String? bookingId,
    String? technicianId,
    String? technicianName,
    double? technicianRating,
    double? proposedPrice,
    String? note,
    String? status,
    DateTime? createdAt,
  }) {
    return BidModel(
      bidId: bidId ?? this.bidId,
      bookingId: bookingId ?? this.bookingId,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      technicianRating: technicianRating ?? this.technicianRating,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
