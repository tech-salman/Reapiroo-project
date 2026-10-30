import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../models/bid_model.dart';
import 'database_service.dart';

class BookingService {
  final DatabaseService _dbService = DatabaseService();

  BookingService();

  /// Creates a new booking request in exact schema
  Future<String> createBookingRequest(BookingModel booking) async {
    final customerId = booking.customerId.isNotEmpty ? booking.customerId : 'demo_customer';
    
    return await _dbService.createBooking(
      customerId: customerId,
      customerName: booking.customerName,
      title: booking.serviceTitle,
      description: booking.description,
      address: booking.address,
      price: booking.budget,
      serviceCategory: booking.category,
      latitude: 0.0,
      longitude: 0.0,
      serviceImageUrl: null,
    );
  }

  /// Streams open requests for technicians with server-side limit and pagination support
  Stream<List<BookingModel>> fetchOpenBookings(
    String techId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _dbService.techRequestsCollection(techId)
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  /// Streams active/past bookings for a customer with server-side limit and pagination support
  Stream<List<BookingModel>> fetchCustomerBookings(
    String customerId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _dbService.customerBookingsCollection(customerId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  /// Streams bookings assigned to a technician with server-side limit and pagination support
  Stream<List<BookingModel>> fetchTechnicianBookings(
    String technicianId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _dbService.techRequestsCollection(technicianId)
        .where('bookedTechId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  /// Places a bid
  Future<void> placeBid(String bookingId, BidModel bid) async {
    await _dbService.submitBid(
      bookingId: bookingId,
      techId: bid.technicianId,
      techName: bid.technicianName,
      bidAmount: bid.proposedPrice,
      proposalNote: bid.note,
      techRating: bid.technicianRating,
      estimatedCompletionTime: '1-2 hours',
      senderRole: 'tech',
      senderName: bid.technicianName,
      status: bid.status,
    );
  }

  /// Streams all bids for a customer's booking
  Stream<List<BidModel>> fetchBidsForCustomerBooking(String customerId, String bookingId) {
    return _dbService.customerBidsCollection(customerId, bookingId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BidModel.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  /// Streams all bids for a tech's request
  Stream<List<BidModel>> fetchBidsForTechRequest(String techId, String bookingId) {
    return _dbService.techBidsCollection(techId, bookingId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BidModel.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  /// Accepts a bid on a booking: updates booking and bid status, generates payment doc.
  Future<void> acceptBid(String customerId, String bookingId, String chosenTechnicianId, String bidId, double agreedPrice) async {
    await _dbService.acceptBid(
      customerId: customerId,
      bookingId: bookingId,
      bidId: bidId,
      techId: chosenTechnicianId,
      amount: agreedPrice,
    );
  }

  Future<void> updateBookingStatus(String customerId, String techId, String bookingId, String newStatus) async {
    await _dbService.updateBookingStatus(customerId, techId, bookingId, newStatus);
  }
}
