import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reapiroo/screens/customer/customer_notification_screen.dart';
import 'package:reapiroo/screens/customer/customer_main_layout.dart';
import 'package:reapiroo/screens/customer/customer_chat_detail_screen.dart';
import 'package:reapiroo/screens/customer/customer_offers_screen.dart';
import 'package:reapiroo/services/chat_service.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/services/storage_service.dart';
import 'package:reapiroo/widgets/booking_card.dart';
import 'package:reapiroo/widgets/notification_bell_button.dart';

class CustomerBookingItem {
  final String id;
  final String techName;
  final String serviceName;
  String location;
  String description;
  final String dateText;
  final String timeText;
  String status; // 'pending', 'booked', 'in_progress', 'completed', 'cancelled'
  bool isSparePartsPaid;
  final String avatarUrl;
  final String serviceImageUrl;
  final List mediaUrls;
  final String? sparePartImageUrl;
  final bool needSpareParts;
  final String? bookedTechId;
  final String? voiceNoteUrl;

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
  };

  factory CustomerBookingItem.fromJson(Map json) {
    List parsedMedia = [];
    if (json['mediaUrls'] != null && json['mediaUrls'] is List) {
      parsedMedia = List.from(json['mediaUrls']);
    }

    final String? techId = json['bookedTechId'] as String? ?? json['assignedTechnicianId'] as String? ?? json['techId'] as String?;
    final String? sparePartImg = json['sparePartImageUrl'] as String? ?? json['sparePartBase64'] as String?;
    final bool needSpare = (json['needSpareParts'] as bool?) ?? (sparePartImg != null && sparePartImg.trim().isNotEmpty);

    final rawTechName = json['techName'] as String? ?? json['bookedTechName'] as String? ?? '';
    final formattedTechName = rawTechName.isNotEmpty
        ? rawTechName
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
      avatarUrl: json['avatarUrl'] ?? json['techAvatar'] ?? '',
      serviceImageUrl: json['serviceImageUrl'] ?? 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=500&auto=format&fit=crop&q=60',
      mediaUrls: parsedMedia,
      sparePartImageUrl: sparePartImg,
      needSpareParts: needSpare,
      bookedTechId: techId,
      voiceNoteUrl: json['voiceNoteUrl'] as String? ?? json['audioUrl'] as String?,
    );
  }
}

class CustomerBookingsScreen extends StatefulWidget {
  final String? initialFilter;
  final bool embedInShell;

  const CustomerBookingsScreen({
    super.key,
    this.initialFilter,
    this.embedInShell = false,
  });

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  late String _selectedStatusFilter;

  bool _isViewingTaskDescription = false;
  CustomerBookingItem? _selectedBooking;

  bool _isLoadingSpareParts = false;
  bool _showTopNotification = false;

  List<CustomerBookingItem> _bookings = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub1;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub2;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub3;
  final Map<String, CustomerBookingItem> _itemsMap = {};

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialFilter ?? 'In Progress';
    _loadBookingsData();
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    _sub3?.cancel();
    super.dispose();
  }

  Future _getUserId() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && authUser.uid.isNotEmpty) {
      return authUser.uid;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email') ?? prefs.getString('phoneNumber') ?? 'customer_default';
  }

  Future _loadBookingsData() async {
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
    _sub2?.cancel();
    _sub3?.cancel();

    _sub1 = DatabaseService().customerBookingsCollection(userId)
        .snapshots()
        .listen((snap) => updateSnapshotDocs(snap.docs));
  }


  Future _updateFirestoreBooking(CustomerBookingItem booking) async {
    try {
      if (booking.id.isNotEmpty && !booking.id.startsWith('ID #')) {
        await DatabaseService().updateRequestStatus(booking.id, booking.status);
      }
    } catch (_) {}
  }

  bool _isVideoMedia(String urlOrPath) {
    final clean = urlOrPath.toLowerCase().trim();
    if (clean.contains('.mp4') ||
        clean.contains('.mov') ||
        clean.contains('.avi') ||
        clean.contains('.mkv') ||
        clean.contains('.webm') ||
        clean.startsWith('data:video')) {
      return true;
    }
    return false;
  }

  void _showMediaPreviewDialog(BuildContext context, String url, bool isVideo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image(
                      image: StorageService.getImageProvider(url),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                if (isVideo)
                  const Positioned.fill(
                    child: Center(
                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 54),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isVideo ? 'Video Preview' : 'Photo Attachment',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBookingDialog(CustomerBookingItem booking) {
    final TextEditingController descController = TextEditingController(text: booking.description);
    final TextEditingController addressController = TextEditingController(text: booking.location);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Request Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Service Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 6),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Location / Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 6),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                final newDesc = descController.text.trim();
                final newAddr = addressController.text.trim();

                try {
                  booking.description = newDesc;
                  booking.location = newAddr;

                  await _updateFirestoreBooking(booking);
                  await _saveBookingsData();

                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Request updated successfully!')),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error updating request: $e')),
                    );
                  }
                }
              },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future _saveBookingsData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _bookings.map((b) => b.toJson()).toList();
    await prefs.setString('customer_bookings_json_list', json.encode(jsonList));
  }



  List<CustomerBookingItem> get _filteredBookings {
    if (_selectedStatusFilter == 'In Progress') {
      return _bookings.where((b) {
        final s = b.status.toLowerCase();
        return s != 'completed' && s != 'cancelled' && s != 'declined' && s != 'rejected';
      }).toList();
    } else if (_selectedStatusFilter == 'Completed') {
      return _bookings.where((b) => b.status.toLowerCase() == 'completed').toList();
    } else if (_selectedStatusFilter == 'Cancelled') {
      return _bookings.where((b) {
        final s = b.status.toLowerCase();
        return s == 'cancelled' || s == 'declined' || s == 'rejected';
      }).toList();
    }
    return _bookings;
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


  Future _handleReschedule(CustomerBookingItem booking) async {
    final messenger = ScaffoldMessenger.of(context);
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 12, minute: 0),
      );

      if (pickedTime != null && mounted) {
        final dateStr = '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
        final timeStr = pickedTime.format(context);
        final updatedBooking = CustomerBookingItem(
          id: booking.id,
          techName: booking.techName,
          serviceName: booking.serviceName,
          location: booking.location,
          description: booking.description,
          dateText: dateStr,
          timeText: timeStr,
          status: booking.status,
          isSparePartsPaid: booking.isSparePartsPaid,
          avatarUrl: booking.avatarUrl,
          serviceImageUrl: booking.serviceImageUrl,
          bookedTechId: booking.bookedTechId,
          mediaUrls: booking.mediaUrls,
          needSpareParts: booking.needSpareParts,
          sparePartImageUrl: booking.sparePartImageUrl,
        );

        setState(() {
          final idx = _bookings.indexWhere((b) => b.id == booking.id);
          if (idx != -1) {
            _bookings[idx] = updatedBooking;
          }
        });

        _saveBookingsData();
        _updateFirestoreBooking(updatedBooking);

        messenger.showSnackBar(
          SnackBar(
            content: Text('Booking rescheduled to $dateStr at $timeStr'),
          ),
        );
      }
    }
  }

  void _handleSparePartsClick(CustomerBookingItem booking) {
    if (_isLoadingSpareParts) return;

    if (booking.isSparePartsPaid) {
      _showSparePartsInvoiceDialog(booking);
      return;
    }

    setState(() {
      _isLoadingSpareParts = true;
    });

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _isLoadingSpareParts = false;
        _showTopNotification = true;
      });

      _showSparePartsInvoiceDialog(booking);
    });
  }

  void _showSparePartsInvoiceDialog(CustomerBookingItem booking) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Spare Parts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                    children: [
                      TextSpan(
                        text: '${booking.techName.split(' ').first} purchased the requested spare parts. Please ',
                      ),
                      const TextSpan(
                        text: 'check invoice',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: booking.isSparePartsPaid ? ' (Settled)' : ' & proceed to pay.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 120,
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 1.0),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(width: 35, height: 4, color: Colors.black54),
                              Container(width: 20, height: 4, color: Colors.black38),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(width: 45, height: 3, color: Colors.black38),
                          const SizedBox(height: 3),
                          Container(width: 60, height: 3, color: Colors.black26),
                          const SizedBox(height: 8),
                          Container(width: double.infinity, height: 1, color: Colors.black26),
                          const Spacer(),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(width: 30, height: 5, color: Colors.black87),
                          ),
                        ],
                      ),
                      Container(
                        width: 75,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black26),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Open',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '20 AED',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                if (booking.isSparePartsPaid)
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                      label: const Text(
                        'Paid',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: const Color(0xFF10B981),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _showPaymentMethodDialog(booking);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Pay',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5E5EA),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentMethodDialog(CustomerBookingItem booking) {
    String selectedMethod = 'card';

    showDialog(
      context: context,
      builder: (paymentDialogContext) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Total: 20 AED',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    icon: Icons.apple,
                    title: 'Apple Pay',
                    isSelected: selectedMethod == 'apple_pay',
                    onTap: () => setModalState(() => selectedMethod = 'apple_pay'),
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentOption(
                    icon: Icons.credit_card,
                    title: 'Credit / Debit Card',
                    subtitle: '**** 4242',
                    isSelected: selectedMethod == 'card',
                    onTap: () => setModalState(() => selectedMethod = 'card'),
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentOption(
                    icon: Icons.payments_outlined,
                    title: 'Cash on Delivery',
                    subtitle: 'Pay to technician',
                    isSelected: selectedMethod == 'cash',
                    onTap: () => setModalState(() => selectedMethod = 'cash'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(paymentDialogContext);

                              setState(() {
                                booking.isSparePartsPaid = true;
                                _showTopNotification = false;
                              });

                              _saveBookingsData();
                              _updateFirestoreBooking(booking);

                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Payment Successful! Spare parts marked as Paid.'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(paymentDialogContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5E5EA),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFE5E5EA),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelBookingDialog(CustomerBookingItem booking) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Do you want to',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const Text(
                'Cancel?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: TextField(
                  controller: reasonController,
                  maxLines: null,
                  style: const TextStyle(fontSize: 15, color: Colors.black),
                  decoration: const InputDecoration(
                    hintText: 'Write your Reason',
                    hintStyle: TextStyle(
                      color: Colors.black38,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(dialogContext);

                          setState(() {
                            booking.status = 'cancelled';
                          });

                          _saveBookingsData();
                          _updateFirestoreBooking(booking);

                          messenger.showSnackBar(
                            const SnackBar(content: Text('Booking Cancelled!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Yes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5E5EA),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'No',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveReviewDialog(CustomerBookingItem booking) {
    int rating = 4;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Leave a Review',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          final isFilled = starIndex <= rating;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                rating = starIndex;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Icon(
                                isFilled ? Icons.star : Icons.star_border,
                                color: const Color(0xFFFFC107),
                                size: 24,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$rating out of 5',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 130,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: TextField(
                    controller: commentController,
                    maxLines: null,
                    style: const TextStyle(fontSize: 15, color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Write your comments',
                      hintStyle: TextStyle(
                        color: Colors.black38,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final commentText = commentController.text.trim();
                            Navigator.pop(dialogContext);

                            setState(() {
                              booking.status = 'completed';
                              _selectedStatusFilter = 'Completed';
                            });

                            _saveBookingsData();
                            _updateFirestoreBooking(booking);

                            try {
                              final prefs = await SharedPreferences.getInstance();
                              final authUser = FirebaseAuth.instance.currentUser;
                              final custName = prefs.getString('firstName') ?? prefs.getString('cust_firstName') ?? authUser?.displayName ?? 'Customer';
                              final custAvatar = prefs.getString('profile_photo_url') ?? prefs.getString('cust_avatar') ?? authUser?.photoURL ?? '';
                              final techId = booking.bookedTechId ?? '';
                              final customerId = await _getUserId();

                              if (techId.isNotEmpty) {
                                await DatabaseService().submitTechnicianReview(
                                  techId: techId,
                                  customerId: customerId,
                                  rating: rating,
                                  comment: commentText.isNotEmpty ? commentText : 'Great service.',
                                  customerName: custName,
                                  customerAvatar: custAvatar,
                                  bookingId: booking.id,
                                );
                              }
                            } catch (_) {}

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Thank you for leaving a review! Booking marked as Completed.'),
                                backgroundColor: Colors.black,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5E5EA),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedInShell) {
      return const CustomerMainLayout(initialIndex: 1);
    }

    if (_isViewingTaskDescription && _selectedBooking != null) {
      return _buildTaskDescriptionView(_selectedBooking!);
    }

    final filteredList = _filteredBookings;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: _buildHeader(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Bookings',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              _buildStatusFilterDropdown(),
            ],
          ),
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
              children: filteredList.map((booking) => BookingCard(
                techName: booking.techName,
                id: booking.id,
                location: booking.location,
                description: booking.description,
                serviceImageUrl: booking.serviceImageUrl,
                dateText: booking.dateText,
                timeText: booking.timeText,
                status: booking.status,
                serviceName: booking.serviceName,
                badgeText: _getBadgeText(booking.status),
                onView: () {
                  setState(() {
                    _selectedBooking = booking;
                    _isViewingTaskDescription = true;
                  });
                },
              )).toList(),
            )
                : _buildEmptyState(),
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

  Widget _buildStatusFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton(
          value: _selectedStatusFilter,
          isDense: true,
          dropdownColor: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          icon: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          items: const [
            DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
            DropdownMenuItem(value: 'Completed', child: Text('Completed')),
            DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
          ],
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedStatusFilter = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            'No $_selectedStatusFilter bookings',
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

  // ==========================================
  // TASK DESCRIPTION SUBVIEW (WITH DYNAMIC STATE & ACTIONS)
  // ==========================================
  Widget _buildTaskDescriptionView(CustomerBookingItem booking) {
    final List allMedia = [];
    if (booking.mediaUrls.isNotEmpty) {
      allMedia.addAll(booking.mediaUrls);
    } else if (booking.serviceImageUrl.isNotEmpty) {
      allMedia.add(booking.serviceImageUrl);
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isViewingTaskDescription = false),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Task Description',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 90.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE5E5EA),
                                  borderRadius: BorderRadius.only(
                                    bottomRight: Radius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  _getBadgeText(booking.status),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      booking.id,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                constraints: const BoxConstraints(maxWidth: 120),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE5E5EA),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  booking.serviceName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder<String>(
                                      future: booking.avatarUrl.isNotEmpty ? Future.value(booking.avatarUrl) : DatabaseService().getUniversalUserAvatar(booking.bookedTechId ?? ''),
                                      builder: (context, snap) {
                                        final avatarUrl = snap.data ?? booking.avatarUrl;
                                        return CircleAvatar(
                                          radius: 22,
                                          backgroundImage: avatarUrl.isNotEmpty ? StorageService.getImageProvider(avatarUrl) : null,
                                          backgroundColor: Colors.grey,
                                          child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 22) : null,
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            booking.techName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 1),
                                          if (booking.isTechAssigned) ...[
                                            const Row(
                                              children: [
                                                Icon(Icons.star, color: Color(0xFFFFC107), size: 13),
                                                SizedBox(width: 2),
                                                Text(
                                                  '4.8',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Text(
                                                  ' (15)',
                                                  style: TextStyle(color: Colors.white70, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ] else ...[
                                            const Text(
                                              'Awaiting technician offers',
                                              style: TextStyle(color: Colors.amberAccent, fontSize: 10.5),
                                            ),
                                          ],
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on_outlined, color: Colors.white70, size: 12),
                                              const SizedBox(width: 3),
                                              Expanded(
                                                child: Text(
                                                  booking.location,
                                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            booking.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 9,
                                              height: 1.15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image(
                                        image: StorageService.getImageProvider(booking.serviceImageUrl),
                                        width: 72,
                                        height: 68,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 72,
                                          height: 68,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Date/Time and Spare Parts Row (Spare Parts button shown ONLY if selected)
                                Row(
                                  children: [
                                    Expanded(
                                      flex: booking.hasSpareParts ? 11 : 1,
                                      child: Container(
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.calendar_month_outlined, size: 12, color: Colors.black),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                booking.dateText,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.access_time_filled, size: 12, color: Colors.black),
                                            const SizedBox(width: 2),
                                            Text(
                                              booking.timeText,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (booking.hasSpareParts) ...[
                                      const SizedBox(width: 6),
                                      Expanded(
                                        flex: 7,
                                        child: GestureDetector(
                                          onTap: () => _handleSparePartsClick(booking),
                                          child: Container(
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: _isLoadingSpareParts
                                                ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation(Colors.black),
                                              ),
                                            )
                                                : Text(
                                              booking.isSparePartsPaid ? 'Spare Parts ✓' : 'Spare Parts',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: booking.isSparePartsPaid ? const Color(0xFF10B981) : Colors.black,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                // Media Attachments (Photos vs Videos - Horizontal Scrollable)
                                if (allMedia.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 125,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: allMedia.length,
                                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                                      itemBuilder: (context, index) {
                                        final mediaItem = allMedia[index];
                                        final isVideo = _isVideoMedia(mediaItem);

                                        return GestureDetector(
                                          onTap: () => _showMediaPreviewDialog(context, mediaItem, isVideo),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              width: allMedia.length == 1
                                                  ? (MediaQuery.of(context).size.width - 64).clamp(200.0, 500.0)
                                                  : 180,
                                              color: Colors.grey.shade900,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Image(
                                                    image: StorageService.getImageProvider(mediaItem),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => Container(
                                                      color: Colors.grey.shade800,
                                                      child: const Icon(Icons.broken_image, color: Colors.white54),
                                                    ),
                                                  ),
                                                  if (isVideo) ...[
                                                    Container(color: Colors.black.withValues(alpha: 0.3)),
                                                    Positioned(
                                                      left: 8,
                                                      top: 8,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text(
                                                          'Video',
                                                          style: TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w800,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Center(
                                                      child: Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          color: Colors.black45,
                                                          shape: BoxShape.circle,
                                                          border: Border.all(color: Colors.white, width: 1.5),
                                                        ),
                                                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    Positioned(
                                                      right: 8,
                                                      top: 8,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black54,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text(
                                                          'Photo',
                                                          style: TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w800,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 8),

                                // Voice Note Waveform Bar
                                if (booking.voiceNoteUrl != null && booking.voiceNoteUrl!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _BookingAudioPlayerWidget(voiceNoteUrl: booking.voiceNoteUrl!.trim()),
                                ],

                                const SizedBox(height: 8),

                                // Action Buttons: Assigned -> Chat / Track / Reschedule. Unassigned -> Offers / Edit
                                if (booking.isTechAssigned) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () async {
                                            final currentCustId = await ChatService.getEffectiveUserId();
                                            final rawTechId = booking.bookedTechId ?? (booking.techName.isNotEmpty ? booking.techName.toLowerCase().replaceAll(' ', '_') : 'tech_demo');
                                            final techId = await DatabaseService().resolveCanonicalTechId(rawTechId);
                                            final customerId = await DatabaseService().resolveUniversalCanonicalId(currentCustId);
                                            final chatId = ChatService.generateChatId(
                                              customerId: customerId,
                                              techId: techId,
                                              bookingId: booking.id,
                                            );
                                            if (!context.mounted) return;
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => CustomerChatDetailScreen(
                                                  chatId: chatId,
                                                  peerId: techId,
                                                  userName: booking.techName.isNotEmpty ? booking.techName : 'Technician',
                                                  userRole: 'Technician',
                                                  avatarUrl: booking.avatarUrl,
                                                  bookingId: booking.id,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'Chat',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (booking.status.toLowerCase() != 'completed') ...[
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Technician is on the way to your location.'),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Track on map',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _handleReschedule(booking),
                                            child: Container(
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFB0B0B4),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Reschedule',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => CustomerOffersScreen(
                                                  requestId: booking.id,
                                                  serviceName: booking.serviceName,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.local_offer_outlined, size: 13, color: Colors.black),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Offers',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _showEditBookingDialog(booking),
                                          child: Container(
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.edit_note, size: 14, color: Colors.black),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Edit',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Bottom Action Row (Mark as done / Completed / Cancel Request)
                    if (booking.status == 'completed') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                          label: const Text(
                            'Completed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: const Color(0xFF10B981),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ] else if (booking.status.toLowerCase() == 'cancelled' || booking.status.toLowerCase() == 'declined' || booking.status.toLowerCase() == 'rejected') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 20),
                          label: const Text(
                            'Canceled',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: Colors.grey,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ] else if (booking.isTechAssigned) ...[
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () => _showLeaveReviewDialog(booking),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Mark as done',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () => _showCancelBookingDialog(booking),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB0B0B4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Cancel',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => _showCancelBookingDialog(booking),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB0B0B4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Cancel Request',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

        // In-App Top Notification Banner
        if (_showTopNotification)
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() => _showTopNotification = false);
                _showSparePartsInvoiceDialog(booking);
              },
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(18),
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Spare Part Purchased',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Your request to purchase spare part has been completed. Please click here to continue',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showTopNotification = false),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.close, color: Colors.white60, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ==========================================
// ISOLATED BOOKING AUDIO PLAYER WIDGET
// ==========================================
class _BookingAudioPlayerWidget extends StatefulWidget {
  final String voiceNoteUrl;
  const _BookingAudioPlayerWidget({required this.voiceNoteUrl});

  @override
  State<_BookingAudioPlayerWidget> createState() => _BookingAudioPlayerWidgetState();
}

class _BookingAudioPlayerWidgetState extends State<_BookingAudioPlayerWidget> {
  bool _isPlayingVoice = false;
  VideoPlayerController? _voiceController;

  @override
  void dispose() {
    _voiceController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_BookingAudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceNoteUrl != widget.voiceNoteUrl) {
      _voiceController?.dispose();
      _voiceController = null;
      _isPlayingVoice = false;
    }
  }

  Future<void> _toggleVoicePlayback(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final cleanUrl = url.trim();

    if (_voiceController == null) {
      if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://') || cleanUrl.startsWith('data:audio')) {
        _voiceController = VideoPlayerController.networkUrl(Uri.parse(cleanUrl));
      } else {
        _voiceController = VideoPlayerController.file(File(cleanUrl));
      }
      await _voiceController!.initialize();
      _voiceController!.setVolume(1.0);
      _voiceController!.addListener(() {
        if (mounted) {
          setState(() {
            _isPlayingVoice = _voiceController!.value.isPlaying;
          });
          if (_voiceController!.value.position >= _voiceController!.value.duration &&
              _voiceController!.value.duration > Duration.zero) {
            _voiceController!.seekTo(Duration.zero);
            _voiceController!.pause();
          }
        }
      });
    }

    if (_voiceController!.value.isPlaying) {
      await _voiceController!.pause();
    } else {
      await _voiceController!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _toggleVoicePlayback(widget.voiceNoteUrl),
          child: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlayingVoice ? Icons.pause : Icons.play_arrow,
              color: Colors.black,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final int barCount = (totalWidth / 5.5).floor().clamp(10, 48);
              const heights = [
                6.0, 10.0, 15.0, 19.0, 12.0, 18.0, 8.0, 14.0,
                20.0, 10.0, 16.0, 11.0, 15.0, 6.0, 12.0, 18.0
              ];

              double progress = 0.0;
              if (_voiceController != null &&
                  _voiceController!.value.isInitialized &&
                  _voiceController!.value.duration.inMilliseconds > 0) {
                progress = (_voiceController!.value.position.inMilliseconds /
                        _voiceController!.value.duration.inMilliseconds)
                    .clamp(0.0, 1.0);
              }
              final int playedBarsCount =
                  (progress * barCount).round().clamp(0, barCount);

              return GestureDetector(
                onTapUp: (details) {
                  if (_voiceController != null &&
                      _voiceController!.value.isInitialized &&
                      _voiceController!.value.duration.inMilliseconds > 0) {
                    final double tapRatio =
                        (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
                    final int newMs =
                        (tapRatio * _voiceController!.value.duration.inMilliseconds).round();
                    _voiceController!.seekTo(Duration(milliseconds: newMs));
                  }
                },
                child: SizedBox(
                  height: 22,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(barCount, (index) {
                      final h = heights[index % heights.length];
                      final bool isActive = index < playedBarsCount;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        width: 2.0,
                        height: h,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF10B981) : Colors.white38,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}