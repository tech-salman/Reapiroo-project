import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reapiroo/providers/services_providers.dart';
import 'package:reapiroo/providers/booking_provider.dart';
import 'package:reapiroo/screens/customer/customer_notification_screen.dart';
import 'package:reapiroo/screens/customer/customer_main_layout.dart';
import 'package:reapiroo/widgets/notification_bell_button.dart';
import 'package:reapiroo/widgets/customer_bookings/customer_booking_filter_header.dart';
import 'package:reapiroo/widgets/customer_bookings/customer_booking_card_item.dart';
import 'package:reapiroo/widgets/customer_bookings/tech_review_modal_sheet.dart';
import 'package:reapiroo/widgets/customer_bookings/booking_details_modal.dart';

class CustomerBookingItem {
  final String id;
  String techName;
  final String serviceName;
  String location;
  String description;
  final String dateText;
  final String timeText;
  String status;
  bool isSparePartsPaid;
  String avatarUrl;
  final String serviceImageUrl;
  final List mediaUrls;
  final String? sparePartImageUrl;
  final bool needSpareParts;
  final String? bookedTechId;
  final String? voiceNoteUrl;
  double rating;
  int ratingCount;

  CustomerBookingItem({
    required this.id,
    required this.techName,
    required this.serviceName,
    required this.location,
    required this.description,
    required this.dateText,
    required this.timeText,
    required this.status,
    this.isSparePartsPaid = false,
    required this.avatarUrl,
    required this.serviceImageUrl,
    this.mediaUrls = const [],
    this.sparePartImageUrl,
    this.needSpareParts = false,
    this.bookedTechId,
    this.voiceNoteUrl,
    this.rating = 4.8,
    this.ratingCount = 15,
  });

  bool get isTechAssigned {
    if (bookedTechId != null && bookedTechId!.trim().isNotEmpty && bookedTechId != 'pending') return true;
    final cleanName = techName.trim().toLowerCase();
    if (cleanName.isEmpty ||
        cleanName.contains('searching') ||
        cleanName.contains('pending') ||
        cleanName == 'customer') {
      return false;
    }
    return status == 'booked' || status == 'in_progress' || status == 'completed';
  }

  bool get hasSpareParts {
    if (needSpareParts) return true;
    if (sparePartImageUrl != null && sparePartImageUrl!.trim().isNotEmpty) return true;
    return false;
  }

  Map toJson() => {
    'id': id,
    'techName': techName,
    'serviceName': serviceName,
    'location': location,
    'description': description,
    'dateText': dateText,
    'timeText': timeText,
    'status': status,
    'isSparePartsPaid': isSparePartsPaid,
    'avatarUrl': avatarUrl,
    'serviceImageUrl': serviceImageUrl,
    'mediaUrls': mediaUrls,
    'sparePartImageUrl': sparePartImageUrl,
    'needSpareParts': needSpareParts,
    'bookedTechId': bookedTechId,
    'voiceNoteUrl': voiceNoteUrl,
    'rating': rating,
    'ratingCount': ratingCount,
  };

  factory CustomerBookingItem.fromJson(Map json) {
    List parsedMedia = [];
    if (json['mediaUrls'] != null && json['mediaUrls'] is List) {
      parsedMedia = List.from(json['mediaUrls']);
    }

    final String? techId = json['bookedTechId'] as String? ?? json['assignedTechnicianId'] as String? ?? json['assignedTechId'] as String? ?? json['techId'] as String?;
    final String? sparePartImg = json['sparePartImageUrl'] as String? ?? json['sparePartBase64'] as String?;
    final bool needSpare = (json['needSpareParts'] as bool?) ?? (sparePartImg != null && sparePartImg.trim().isNotEmpty);

    final rawTechName = json['bookedTechName'] as String? ?? json['techName'] as String? ?? json['assignedTechName'] as String? ?? '';
    final cleanTechName = rawTechName.trim();
    final bool isGenericTechName = cleanTechName.isEmpty ||
        cleanTechName.toLowerCase() == 'technician' ||
        cleanTechName.toLowerCase() == 'tech' ||
        cleanTechName.toLowerCase() == 'customer';

    final formattedTechName = !isGenericTechName
        ? cleanTechName
        : (techId != null && techId.isNotEmpty && techId != 'pending'
        ? 'Technician'
        : 'Searching for Technician...');

    String loc = 'Downtown Road, Dubai.';
    if (json['location'] != null) {
      if (json['location'] is Map) {
        loc = json['location']['address'] as String? ?? 'Downtown Road, Dubai.';
      } else if (json['location'] is String && (json['location'] as String).isNotEmpty) {
        loc = json['location'] as String;
      }
    } else if (json['address'] != null && (json['address'] as String).isNotEmpty) {
      loc = json['address'] as String;
    }

    String title = json['serviceName'] ?? json['serviceTitle'] ?? json['title'] ?? 'Home Service';
    String desc = json['description'] ?? json['notes'] ?? 'Task required.';

    final techAvatarUrl = json['bookedTechAvatar'] as String? ??
        json['techAvatar'] as String? ??
        json['assignedTechAvatar'] as String? ??
        '';

    final double parsedRating = (json['techRating'] as num?)?.toDouble() ??
        (json['technicianRating'] as num?)?.toDouble() ??
        (json['rating'] as num?)?.toDouble() ??
        4.8;

    final int parsedRatingCount = (json['ratingCount'] as num?)?.toInt() ??
        (json['reviewCount'] as num?)?.toInt() ??
        (json['totalReviews'] as num?)?.toInt() ??
        15;

    return CustomerBookingItem(
      id: json['id'] ?? json['bookingId'] ?? json['requestId'] ?? 'ID # 2145',
      techName: formattedTechName,
      serviceName: title,
      location: loc,
      description: desc,
      dateText: json['dateText'] ?? 'Mon, Dec 23',
      timeText: json['timeText'] ?? '12:00',
      status: json['status'] ?? 'open',
      isSparePartsPaid: json['isSparePartsPaid'] ?? false,
      avatarUrl: techAvatarUrl,
      serviceImageUrl: json['serviceImageUrl'] ?? 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=500&auto=format&fit=crop&q=60',
      mediaUrls: parsedMedia,
      sparePartImageUrl: sparePartImg,
      needSpareParts: needSpare,
      bookedTechId: techId,
      voiceNoteUrl: json['voiceNoteUrl'] as String? ?? json['audioUrl'] as String?,
      rating: parsedRating,
      ratingCount: parsedRatingCount,
    );
  }
}

class CustomerBookingsScreen extends ConsumerStatefulWidget {
  final String? initialFilter;
  final bool embedInShell;

  const CustomerBookingsScreen({
    super.key,
    this.initialFilter,
    this.embedInShell = false,
  });

  @override
  ConsumerState<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends ConsumerState<CustomerBookingsScreen> {
  CustomerBookingItem? _selectedBooking;
  List<CustomerBookingItem> _bookings = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub1;
  final Map<String, CustomerBookingItem> _itemsMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialFilter != null) {
        ref.read(customerBookingsStateProvider.notifier).setFilter(widget.initialFilter!);
      }
    });
    _loadBookingsData();
  }

  @override
  void dispose() {
    _sub1?.cancel();
    super.dispose();
  }

  Future<String> _getUserId() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && authUser.uid.isNotEmpty) {
      return authUser.uid;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email') ?? prefs.getString('phoneNumber') ?? 'customer_default';
  }

  Future<void> _loadBookingsData() async {
    final userId = await _getUserId();
    final authUser = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('email') ?? '';
    final userPhone = prefs.getString('phoneNumber') ?? '';

    void updateSnapshotDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
      bool changed = false;
      for (final doc in docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final cId = (data['customerId'] as String? ?? '').trim();
        final path = doc.reference.path;

        bool isMyBooking = cId.isEmpty ||
            cId == userId ||
            (authUser != null && cId == authUser.uid) ||
            (userEmail.isNotEmpty && cId == userEmail) ||
            (userPhone.isNotEmpty && cId == userPhone) ||
            path.contains(userId) ||
            (authUser != null && path.contains(authUser.uid)) ||
            cId == 'cust_123' ||
            cId == 'customer_default' ||
            userId == 'customer_default';

        if (isMyBooking) {
          data['id'] = data['bookingId'] ?? data['requestId'] ?? doc.id;
          final item = CustomerBookingItem.fromJson(data);
          _itemsMap[item.id] = item;
          changed = true;
        }
      }

      if (changed && mounted) {
        final list = _itemsMap.values.toList();
        list.sort((a, b) => b.id.compareTo(a.id));
        setState(() {
          _bookings = list;
          if (_selectedBooking != null) {
            final updated = _bookings.firstWhere(
              (b) => b.id == _selectedBooking!.id,
              orElse: () => _selectedBooking!,
            );
            _selectedBooking = updated;
          }
        });
      }
    }

    _sub1?.cancel();
    final dbService = ref.read(databaseServiceProvider);
    _sub1 = dbService.customerBookingsCollection(userId)
        .snapshots()
        .listen((snap) => updateSnapshotDocs(snap.docs));
  }

  String _getBadgeText(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'in_progress':
      case 'open':
      case 'pending':
      case 'open_request':
      case 'booked':
      case 'bid_accepted':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
      case 'declined':
      case 'rejected':
        return 'Cancelled';
      default:
        return 'In Progress';
    }
  }

  List<CustomerBookingItem> _filteredBookingsWithFilter(String statusFilter) {
    if (statusFilter == 'In Progress') {
      return _bookings.where((b) {
        final s = b.status.toLowerCase();
        return s != 'completed' && s != 'cancelled' && s != 'declined' && s != 'rejected';
      }).toList();
    } else if (statusFilter == 'Completed') {
      return _bookings.where((b) => b.status.toLowerCase() == 'completed').toList();
    } else if (statusFilter == 'Cancelled') {
      return _bookings.where((b) {
        final s = b.status.toLowerCase();
        return s == 'cancelled' || s == 'declined' || s == 'rejected';
      }).toList();
    }
    return _bookings;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedInShell) {
      return const CustomerMainLayout(initialIndex: 1);
    }

    final bookingsState = ref.watch(customerBookingsStateProvider);
    final bookingsController = ref.read(customerBookingsStateProvider.notifier);

    if (bookingsState.isViewingTechReviews && _selectedBooking != null) {
      return TechReviewModalSheet(
        techName: _selectedBooking!.techName,
        avatarUrl: _selectedBooking!.avatarUrl,
        rating: _selectedBooking!.rating,
        ratingCount: _selectedBooking!.ratingCount,
        reviews: [],
        onBackPressed: () => bookingsController.selectBooking(null, techReviews: false),
      );
    }

    if (bookingsState.isViewingTaskDescription && _selectedBooking != null) {
      return BookingDetailsModal(
        bookingId: _selectedBooking!.id,
        serviceName: _selectedBooking!.serviceName,
        description: _selectedBooking!.description,
        location: _selectedBooking!.location,
        dateText: _selectedBooking!.dateText,
        timeText: _selectedBooking!.timeText,
        status: _selectedBooking!.status,
        badgeText: _getBadgeText(_selectedBooking!.status),
        techName: _selectedBooking!.techName,
        avatarUrl: _selectedBooking!.avatarUrl,
        rating: _selectedBooking!.rating,
        ratingCount: _selectedBooking!.ratingCount,
        onBackPressed: () => bookingsController.selectBooking(null, taskDescription: false),
        onViewTechReviews: () => bookingsController.selectBooking(_selectedBooking!.id, techReviews: true),
        onChatPressed: () {
          // Navigate to chat detail
        },
        onCancelPressed: () {
          // Cancel booking
        },
      );
    }

    final filteredList = _filteredBookingsWithFilter(bookingsState.selectedFilter);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: _buildHeader(),
        ),
        CustomerBookingFilterHeader(
          selectedStatusFilter: bookingsState.selectedFilter,
          onFilterChanged: (val) {
            if (val != null) {
              bookingsController.setFilter(val);
            }
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 120.0,
            ),
            child: filteredList.isNotEmpty
                ? Column(
                    children: filteredList.map((booking) => CustomerBookingCardItem(
                      id: booking.id,
                      techName: booking.techName,
                      serviceName: booking.serviceName,
                      location: booking.location,
                      description: booking.description,
                      dateText: booking.dateText,
                      timeText: booking.timeText,
                      status: booking.status,
                      serviceImageUrl: booking.serviceImageUrl,
                      badgeText: _getBadgeText(booking.status),
                      onView: () {
                        setState(() {
                          _selectedBooking = booking;
                        });
                        bookingsController.selectBooking(booking.id, taskDescription: true);
                      },
                    )).toList(),
                  )
                : _buildEmptyStateForFilter(bookingsState.selectedFilter),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: Builder(
            builder: (context) => IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.menu, color: Colors.white, size: 22),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        const Spacer(),
        NotificationBellButton(
          isTech: false,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CustomerNotificationScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyStateForFilter(String filter) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No $filter bookings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
