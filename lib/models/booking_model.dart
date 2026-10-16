import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String bookingId;
  final String customerId;
  final String customerName;
  final String serviceTitle;
  final String category;
  final String description;
  final String address;
  final double budget;
  final String status; // 'open', 'bid_accepted', 'in_progress', 'completed', 'cancelled'
  final String? assignedTechnicianId;
  final double agreedPrice;
  final DateTime? createdAt;
  final DateTime? completedAt;

  // Additional helper fields for UI compatibility
  final String date;
  final String time;
  final String technicianName;
  final double technicianRating;

  BookingModel({
    String? bookingId,
    String? id,
    String? customerId,
    String? customerName,
    required this.serviceTitle,
    required this.category,
    String description = '',
    String? notes,
    required this.address,
    double? budget,
    double? price,
    this.status = 'open',
    this.assignedTechnicianId,
    this.agreedPrice = 0.0,
    this.createdAt,
    this.completedAt,
    this.date = '',
    this.time = '',
    this.technicianName = '',
    this.technicianRating = 0.0,
  })  : bookingId = bookingId ?? id ?? '',
        customerId = customerId ?? '',
        customerName = customerName ?? '',
        budget = budget ?? price ?? 0.0,
        description = description.isNotEmpty ? description : (notes ?? '');

  // Backward compatibility getters
  String get id => bookingId;
  double get price => agreedPrice > 0 ? agreedPrice : budget;
  String get notes => description;
  String? get bookedTechId => (assignedTechnicianId != null && assignedTechnicianId!.isNotEmpty) ? assignedTechnicianId : null;
  String get techName => technicianName;
  String get avatarUrl => '';
  bool get isTechAssigned => (assignedTechnicianId != null && assignedTechnicianId!.isNotEmpty) || status == 'booked' || status == 'in_progress' || status == 'completed';

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'customerId': customerId,
      'customerName': customerName,
      'serviceTitle': serviceTitle,
      'category': category,
      'description': description,
      'address': address,
      'budget': budget,
      'status': status,
      'assignedTechnicianId': assignedTechnicianId,
      'agreedPrice': agreedPrice,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'date': date,
      'time': time,
      'technicianName': technicianName,
      'technicianRating': technicianRating,
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return BookingModel(
      bookingId: docId ?? map['bookingId'] as String? ?? map['id'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      serviceTitle: map['serviceTitle'] as String? ?? map['title'] as String? ?? '',
      category: map['category'] as String? ?? '',
      description: map['description'] as String? ?? map['notes'] as String? ?? '',
      address: map['address'] as String? ?? '',
      budget: (map['budget'] as num?)?.toDouble() ?? (map['price'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'open',
      assignedTechnicianId: map['assignedTechnicianId'] as String? ?? map['bookedTechId'] as String?,
      agreedPrice: (map['agreedPrice'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDateTime(map['createdAt']),
      completedAt: parseDateTime(map['completedAt']),
      date: map['date'] as String? ?? '',
      time: map['time'] as String? ?? '',
      technicianName: map['technicianName'] as String? ?? '',
      technicianRating: (map['technicianRating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  BookingModel copyWith({
    String? bookingId,
    String? id,
    String? customerId,
    String? customerName,
    String? serviceTitle,
    String? category,
    String? description,
    String? notes,
    String? address,
    double? budget,
    double? price,
    String? status,
    String? assignedTechnicianId,
    double? agreedPrice,
    DateTime? createdAt,
    DateTime? completedAt,
    String? date,
    String? time,
    String? technicianName,
    double? technicianRating,
  }) {
    return BookingModel(
      bookingId: bookingId ?? id ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      category: category ?? this.category,
      description: description ?? notes ?? this.description,
      address: address ?? this.address,
      budget: budget ?? price ?? this.budget,
      status: status ?? this.status,
      assignedTechnicianId: assignedTechnicianId ?? this.assignedTechnicianId,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      date: date ?? this.date,
      time: time ?? this.time,
      technicianName: technicianName ?? this.technicianName,
      technicianRating: technicianRating ?? this.technicianRating,
    );
  }
}
