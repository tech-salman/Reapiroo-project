import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking_model.dart';
import '../models/bid_model.dart';
import 'auth_provider.dart';
import 'services_providers.dart';

/// Stream provider for customer's bookings
final customerBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);

  final bookingService = ref.watch(bookingServiceProvider);
  return bookingService.fetchCustomerBookings(user.uid);
});

/// Stream provider for technician's open available task requests
final techOpenBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);

  final bookingService = ref.watch(bookingServiceProvider);
  return bookingService.fetchOpenBookings(user.uid);
});

/// Stream provider for technician's assigned bookings
final techAssignedBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);

  final bookingService = ref.watch(bookingServiceProvider);
  return bookingService.fetchTechnicianBookings(user.uid);
});

/// Stream provider for bids submitted on a specific booking ID
final bookingBidsStreamProvider = StreamProvider.family<List<BidModel>, String>((ref, bookingId) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null || bookingId.isEmpty) return Stream.value([]);

  final bookingService = ref.watch(bookingServiceProvider);
  return bookingService.fetchBidsForCustomerBooking(user.uid, bookingId);
});

/// Controller for performing booking actions (creating requests, submitting bids, accepting bids, updating statuses)
class BookingController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<String?> createBookingRequest(BookingModel booking) async {
    state = const AsyncValue.loading();
    String? createdId;
    try {
      final bookingService = ref.read(bookingServiceProvider);
      createdId = await bookingService.createBookingRequest(booking);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    return createdId;
  }

  Future<void> placeBid(String bookingId, BidModel bid) async {
    state = const AsyncValue.loading();
    try {
      final bookingService = ref.read(bookingServiceProvider);
      await bookingService.placeBid(bookingId, bid);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acceptBid({
    required String customerId,
    required String bookingId,
    required String techId,
    required String bidId,
    required double agreedPrice,
  }) async {
    state = const AsyncValue.loading();
    try {
      final bookingService = ref.read(bookingServiceProvider);
      await bookingService.acceptBid(customerId, bookingId, techId, bidId, agreedPrice);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateBookingStatus({
    required String customerId,
    required String techId,
    required String bookingId,
    required String newStatus,
  }) async {
    state = const AsyncValue.loading();
    try {
      final bookingService = ref.read(bookingServiceProvider);
      await bookingService.updateBookingStatus(customerId, techId, bookingId, newStatus);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final bookingControllerProvider = AsyncNotifierProvider<BookingController, void>(() {
  return BookingController();
});
