import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/providers/services_providers.dart';
import 'package:reapiroo/services/chat_service.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/screens/tech/tech_main_layout.dart';
import 'package:reapiroo/screens/tech/new_task_screen.dart';
import 'package:reapiroo/screens/tech/tech_chat_detail_screen.dart';
import 'package:reapiroo/widgets/custom_bottom_nav_bar.dart';
import 'package:reapiroo/widgets/task_description_card.dart';

class TaskDescriptionScreen extends ConsumerStatefulWidget {
  final String? requestId;
  final int initialIndex;

  const TaskDescriptionScreen({
    super.key,
    this.requestId,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<TaskDescriptionScreen> createState() => _TaskDescriptionScreenState();
}

class _TaskDescriptionScreenState extends ConsumerState<TaskDescriptionScreen> {
  late int _currentNavIndex;

  String _customerName = 'Customer';
  String customerId = 'cust_123';
  String _customerAvatar = '';
  String _serviceName = 'Plumbing';
  String _location = 'Downtown Road, Dubai.';
  String _description = 'I need to have my outdoor pipes fixed.';
  String _serviceImageUrl = 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=500&auto=format&fit=crop&q=60';
  String? _sparePartImageUrl;
  String? _voiceNoteUrl;
  List<String> _mediaUrls = [];
  double? _latitude;
  double? _longitude;

  String _currentTechId = '';
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialIndex;
    _loadRequestData();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final uid = await ChatService.getEffectiveUserId();
    if (mounted) setState(() => _currentTechId = uid);
  }

  Future<void> _loadRequestData() async {
    if (widget.requestId != null && widget.requestId!.isNotEmpty) {
      try {
        Map<String, dynamic>? data;
        final prefs = await SharedPreferences.getInstance();
        final currentTechId = _currentTechId.isNotEmpty ? _currentTechId : (FirebaseAuth.instance.currentUser?.uid ?? prefs.getString('phoneNumber') ?? '');

        if (currentTechId.isNotEmpty) {
          final doc = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collection('techs').doc(currentTechId).collection('requests').doc(widget.requestId).get();
          if (doc.exists && doc.data() != null) {
            data = doc.data();
          }
        }
        if (data == null) {
          final techIndexDoc = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collection('techs').doc('TECH_INDEX').get();
          if (techIndexDoc.exists) {
            final tIds = (techIndexDoc.data()?['techIds'] as List<dynamic>? ?? []).map((e) => e.toString());
            for (final tId in tIds) {
              final doc = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collection('techs').doc(tId).collection('requests').doc(widget.requestId).get();
              if (doc.exists && doc.data() != null) {
                data = doc.data();
                break;
              }
            }
          }
        }

        if (data != null) {
          String fetchedAvatar = '';
          final rawCustId = (data['customerId'] as String? ?? data['uid'] as String? ?? '').trim();
          final custId = rawCustId.isNotEmpty ? rawCustId : 'cust_demo';
          if (custId.isNotEmpty) {
            try {
              final custDoc = await ref.read(databaseServiceProvider).getCustomerProfile(custId);
              if (custDoc.exists && custDoc.data() != null) {
                fetchedAvatar = custDoc.data()!['avatarUrl'] as String? ?? '';
              }
            } catch (_) {}
          }
          if (mounted) {
            setState(() {
              _customerName = data?['customerName'] as String? ?? 'Customer';
              customerId = custId;
              _customerAvatar = fetchedAvatar;
              _serviceName = data?['title'] as String? ?? 'Service';
              _location = data?['address'] as String? ?? 'Location';
              _description = data?['description'] as String? ?? '';
              _latitude = (data?['latitude'] as num?)?.toDouble();
              _longitude = (data?['longitude'] as num?)?.toDouble();
              _status = data?['status'] as String? ?? 'pending';
              _serviceImageUrl = data?['serviceImageUrl'] as String? ?? 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=500&auto=format&fit=crop&q=60';
              _sparePartImageUrl = data?['sparePartImageUrl'] as String?;
              _voiceNoteUrl = data?['voiceNoteUrl'] as String? ?? data?['audioUrl'] as String?;
              if (data?['mediaUrls'] != null && data?['mediaUrls'] is List) {
                _mediaUrls = List<String>.from(data?['mediaUrls']);
              }
            });
            return;
          }
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('customer_request_service_name') ?? 'Plumbing';
    final loc = prefs.getString('customer_request_location') ?? 'Downtown Road, Dubai.';
    final desc = prefs.getString('customer_request_description') ?? 'I need to have my outdoor pipes fixed.';
    final img = prefs.getString('customer_request_service_image') ?? 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=500&auto=format&fit=crop&q=60';
    final sparePart = prefs.getString('customer_request_spare_part');
    final voiceNote = prefs.getString('customer_request_voice_note');
    final mediaStr = prefs.getString('customer_request_media');
    final lat = prefs.getDouble('user_latitude');
    final lng = prefs.getDouble('user_longitude');

    List<String> mediaList = [];
    if (mediaStr != null && mediaStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(mediaStr);
        mediaList = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _serviceName = name;
      _location = loc;
      _description = desc;
      _serviceImageUrl = img;
      _sparePartImageUrl = sparePart;
      _voiceNoteUrl = voiceNote;
      _mediaUrls = mediaList;
      _latitude = lat;
      _longitude = lng;
    });
  }

  static const List<CustomNavItem> _navItems = [
    CustomNavItem(icon: Icons.home, label: 'Home'),
    CustomNavItem(icon: Icons.calendar_month_outlined, label: 'Requests'),
    CustomNavItem(icon: Icons.chat_bubble_rounded, label: 'Chat'),
    CustomNavItem(icon: Icons.person, label: 'Profile'),
  ];

  Future<void> _openMaps() async {
    Uri googleMapsUrl;
    if (_latitude != null && _longitude != null) {
      googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$_latitude,$_longitude');
    } else {
      googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_location)}');
    }

    try {
      final bool launched = await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        final fallbackUri = Uri.parse('https://maps.google.com/?q=${_latitude != null ? '$_latitude,$_longitude' : Uri.encodeComponent(_location)}');
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch maps: $e')),
        );
      }
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _requestStream() {
    if (widget.requestId == null || widget.requestId!.isEmpty) {
      return const Stream.empty();
    }
    if (_currentTechId.isNotEmpty) {
      return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collection('techs').doc(_currentTechId).collection('requests').doc(widget.requestId).snapshots();
    }
    return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collection('techs').doc('tech_demo').collection('requests').doc(widget.requestId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _requestStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
          final data = snapshot.data!.data()!;
          _serviceName = data['title'] as String? ?? _serviceName;
          _location = data['address'] as String? ?? _location;
          _description = data['description'] as String? ?? _description;
          _status = data['status'] as String? ?? _status;
          _serviceImageUrl = data['serviceImageUrl'] as String? ?? _serviceImageUrl;
          _sparePartImageUrl = data['sparePartImageUrl'] as String?;
          _voiceNoteUrl = data['voiceNoteUrl'] as String? ?? data['audioUrl'] as String? ?? _voiceNoteUrl;
          if (data['mediaUrls'] != null && data['mediaUrls'] is List) {
            _mediaUrls = List<String>.from(data['mediaUrls']);
          }
          _latitude = (data['latitude'] as num?)?.toDouble() ?? _latitude;
          _longitude = (data['longitude'] as num?)?.toDouble() ?? _longitude;
        }

        return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: _buildTopBar(context),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                  child: Text(
                    _serviceName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 120.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TaskDescriptionCard(
                          customerName: _customerName,
                          requestId: widget.requestId,
                          location: _location,
                          description: _description,
                          serviceImageUrl: _serviceImageUrl,
                          serviceName: _serviceName,
                          date: 'Mon, Dec 23',
                          time: '12:00',
                          sparePartImageUrl: _sparePartImageUrl,
                          voiceNoteUrl: _voiceNoteUrl,
                          mediaUrls: _mediaUrls,
                          onChatPressed: () async {
                            final currentTechId = await ChatService.getEffectiveUserId();
                            final techId = await DatabaseService().resolveCanonicalTechId(currentTechId);
                            final custId = await DatabaseService().resolveUniversalCanonicalId(customerId);

                            final prefs = await SharedPreferences.getInstance();
                            final fname = prefs.getString('firstName') ?? prefs.getString('tech_firstName') ?? 'Technician';
                            final lname = prefs.getString('lastName') ?? prefs.getString('tech_lastName') ?? '';
                            final techName = '$fname $lname'.trim().isEmpty ? 'Technician' : '$fname $lname'.trim();

                            final chatId = ChatService.generateChatId(
                              customerId: custId,
                              techId: techId,
                              bookingId: widget.requestId,
                            );

                            try {
                              final chatService = ChatService();
                              final targetBookingId = widget.requestId ?? '';
                              final messagesSnap = await ref.read(databaseServiceProvider).techMessagesCollection(techId, chatId)
                                  .where('isBookingCard', isEqualTo: true)
                                  .get();

                              bool alreadySent = false;
                              for (var doc in messagesSnap.docs) {
                                final data = doc.data();
                                final bId = data['bookingId'] as String? ?? '';
                                if (bId == targetBookingId) {
                                  alreadySent = true;
                                  break;
                                }
                              }

                              if (!alreadySent) {
                                await chatService.sendMessage(
                                  chatId: chatId,
                                  senderId: techId,
                                  receiverId: custId,
                                  text: 'Booking Card: $_serviceName',
                                  senderName: techName,
                                  customerId: custId,
                                  techId: techId,
                                  isBookingCard: true,
                                  bookingId: widget.requestId ?? '',
                                  serviceName: _serviceName,
                                  location: _location,
                                  description: _description,
                                  serviceImageUrl: _serviceImageUrl,
                                  dateText: 'Mon, Dec 23',
                                  timeText: '12:00',
                                  status: 'Assigned',
                                  badgeText: 'Booking',
                                  techName: techName,
                                );
                              }
                            } catch (_) {}

                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TechChatDetailScreen(
                                  chatId: chatId,
                                  peerId: customerId,
                                  userName: _customerName,
                                  userRole: 'Customer',
                                  avatarUrl: _customerAvatar,
                                  bookingId: widget.requestId,
                                ),
                              ),
                            );
                          },
                          onOpenMapsPressed: _openMaps,
                          onViewPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NewTaskScreen(
                                  requestId: widget.requestId,
                                  serviceName: _serviceName,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildRealtimeBidsBanner(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: _buildBottomActionButtons(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: AnimatedCurvedNavBar(
                items: _navItems,
                currentIndex: _currentNavIndex,
                onTap: (index) {
                  if (index == widget.initialIndex) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TechMainLayout(initialIndex: index),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'Task Description',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Future<void> _markTaskAsDone() async {
    if (widget.requestId != null && widget.requestId!.isNotEmpty) {
      try {
        final dbService = ref.read(databaseServiceProvider);
        // Set status to pending_customer_confirmation instead of completed
        await dbService.updateRequestStatus(widget.requestId!, 'pending_customer_confirmation');

        // Send notification to customer to confirm task completion
        if (customerId.isNotEmpty) {
          await dbService.addNotification(
            recipientId: customerId,
            title: 'Task Completion Pending Confirmation',
            description: 'The technician has marked "$_serviceName" as done. Please review and confirm the task is completed.',
            type: 'task_confirmation',
            targetId: widget.requestId!,
            isTech: false,
          );
        }
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tech_request_status', 'pending_customer_confirmation');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task marked as done! Waiting for customer confirmation.'),
        backgroundColor: Colors.black,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => TechMainLayout(initialIndex: widget.initialIndex)),
      (route) => false,
    );
  }

  void _showTaskCancelDialog(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                  height: 140,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: reasonController,
                    maxLines: null,
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
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            if (widget.requestId != null && widget.requestId!.isNotEmpty) {
                              try {
                                await ref.read(databaseServiceProvider).updateRequestStatus(widget.requestId!, 'cancelled');
                              } catch (_) {}
                            }
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('tech_request_status', 'cancelled');
                            navigator.pop(); // Close dialog
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Task Cancelled!'),
                                backgroundColor: Colors.black,
                              ),
                            );
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => TechMainLayout(initialIndex: widget.initialIndex)),
                              (route) => false,
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
                            Navigator.pop(context); // Close dialog
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5E5EA),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            side: const BorderSide(color: Colors.black, width: 1.5),
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
        );
      },
    );
  }

  void _showBidNegotiationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return _BidNegotiationContent(
          requestId: widget.requestId ?? 'req_latest',
          serviceName: _serviceName,
        );
      },
    );
  }

  Widget _buildRealtimeBidsBanner() {
    final s = _status.toLowerCase();
    if (s == 'completed' || s == 'cancelled' || s == 'declined' || s == 'rejected' || s == 'pending_customer_confirmation') {
      return const SizedBox.shrink();
    }
    final reqId = widget.requestId ?? '';
    if (reqId.isEmpty) return const SizedBox.shrink();

    // use _currentUserId if available, else a fast async lookup isn't possible in a sync build method easily.
    // wait, we can just omit techId or use a FutureBuilder. We'll use collectionGroup fallback if empty.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.read(databaseServiceProvider).streamBidsForBooking(reqId, techId: _currentTechId.isNotEmpty ? _currentTechId : null),
      builder: (context, snapshot) {
        final rawDocs = snapshot.data?.docs ?? [];
        final cleanWId = reqId.replaceAll('ID #', '').trim();

        final bidDocs = rawDocs.where((doc) {
          final data = doc.data();
          final bId = (data['bookingId'] as String? ?? '').replaceAll('ID #', '').trim();
          final rId = (data['requestId'] as String? ?? '').replaceAll('ID #', '').trim();
          final path = doc.reference.path;

          return bId == reqId ||
              rId == reqId ||
              bId == cleanWId ||
              rId == cleanWId ||
              bId.toLowerCase() == cleanWId.toLowerCase() ||
              rId.toLowerCase() == cleanWId.toLowerCase() ||
              path.contains(reqId) ||
              path.contains(cleanWId);
        }).toList();

        if (bidDocs.isEmpty) return const SizedBox.shrink();

        bidDocs.sort((a, b) {
          final tsA = a.data()['createdAt'] ?? a.data()['timestamp'] ?? a.data()['updatedAt'];
          final tsB = b.data()['createdAt'] ?? b.data()['timestamp'] ?? b.data()['updatedAt'];
          if (tsA is Timestamp && tsB is Timestamp) {
            return tsA.compareTo(tsB);
          }
          return 0;
        });

        final latest = bidDocs.last.data();
        final senderRole = latest['senderRole'] as String? ?? 'tech';
        final amount = (latest['amount'] as num?)?.toDouble() ?? (latest['price'] as num?)?.toDouble() ?? 0.0;
        final status = latest['status'] as String? ?? 'pending';

        if (senderRole == 'customer' && status == 'pending') {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Color(0xFF047857), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Customer Counter-Bid',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                      Text(
                        'Customer offered AED ${amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showBidNegotiationBottomSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Respond', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBottomActionButtons() {
    final s = _status.toLowerCase();
    if (s == 'completed') {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Task Completed',
          style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 15),
        ),
      );
    }
    if (s == 'pending_customer_confirmation') {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Awaiting Customer Confirmation',
          style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 15),
        ),
      );
    }
    if (s == 'cancelled' || s == 'declined' || s == 'rejected') {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          s == 'cancelled' ? 'Task Cancelled' : 'Task Rejected',
          style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 15),
        ),
      );
    }

    if (s == 'accepted' || s == 'in_progress' || s == 'booked' || s == 'bid_accepted') {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _markTaskAsDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Mark as done',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => _showTaskCancelDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB5B5B8),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => _showBidNegotiationBottomSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Submit Offer',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => _showTaskCancelDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5B5B8), // Gray for reject
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Reject',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BidNegotiationContent extends ConsumerStatefulWidget {
  final String requestId;
  final String serviceName;

  const _BidNegotiationContent({
    required this.requestId,
    required this.serviceName,
  });

  @override
  ConsumerState<_BidNegotiationContent> createState() => _BidNegotiationContentState();
}

enum _BidStage { entering, waiting }

class _BidNegotiationContentState extends ConsumerState<_BidNegotiationContent> {
  String _enteredAmount = '';
  _BidStage _stage = _BidStage.entering;
  bool _isSubmitting = false;
  String _currentTechId = '';

  @override
  void initState() {
    super.initState();
    _loadTechId();
  }

  Future<void> _loadTechId() async {
    final uid = await ChatService.getEffectiveUserId();
    if (mounted) setState(() => _currentTechId = uid);
  }

  String _cleanRequestId(String? raw) {
    if (raw == null) return '';
    var id = raw.replaceAll('ID #', '').trim();
    return id;
  }

  Future<String> _getTargetRequestId() async {
    String id = _cleanRequestId(widget.requestId);

    if (id.isEmpty || id == 'demo_request_id') {
      try {
        final techId = _currentTechId.isNotEmpty ? _currentTechId : 'tech_demo';
        final dbService = ref.read(databaseServiceProvider);
        
        final reqSnap = await dbService.techRequestsCollection(techId).get();
        if (reqSnap.docs.isNotEmpty) {
          final data = reqSnap.docs.last.data();
          id = data['bookingId'] as String? ?? data['requestId'] as String? ?? reqSnap.docs.last.id;
        }
      } catch (_) {}
    }
    return id.isEmpty ? 'demo_request_id' : id;
  }

  void _onKeyPressed(String val) {
    setState(() {
      if (_enteredAmount.length < 6) {
        _enteredAmount += val;
      }
    });
  }

  void _onBackspace() {
    if (_enteredAmount.isNotEmpty) {
      setState(() {
        _enteredAmount = _enteredAmount.substring(0, _enteredAmount.length - 1);
      });
    }
  }

  Future<void> _sendBid() async {
    if (_enteredAmount.isEmpty || _isSubmitting) return;
    final double price = double.tryParse(_enteredAmount) ?? 150.0;

    final authUser = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final techId = _currentTechId.isNotEmpty ? _currentTechId : 'tech_demo';
    final techName = authUser?.displayName ?? prefs.getString('firstName') ?? prefs.getString('tech_firstName') ?? 'Technician';

    final targetRequestId = await _getTargetRequestId();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final dbService = ref.read(databaseServiceProvider);
      await dbService.submitBid(
        bookingId: targetRequestId,
        techId: techId,
        techName: techName,
        bidAmount: price,
        proposalNote: 'Technician offer for ${widget.serviceName}',
        senderRole: 'tech',
        senderName: techName,
      );

      if (!mounted) return;
      setState(() {
        _stage = _BidStage.waiting;
        _enteredAmount = '';
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bid of AED ${price.toStringAsFixed(0)} sent to customer in real-time!'),
          backgroundColor: Colors.black,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting bid: $e')),
      );
    }
  }

  Future<void> _acceptCustomerBid(double amount, String techId, String targetRequestId) async {
    setState(() => _isSubmitting = true);
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final currentTechId = authUser?.uid ?? prefs.getString('phoneNumber') ?? prefs.getString('email') ?? techId;
      final techName = authUser?.displayName ?? prefs.getString('firstName') ?? prefs.getString('tech_firstName') ?? 'Technician';
      final dbService = ref.read(databaseServiceProvider);

      await dbService.submitBid(
        bookingId: targetRequestId,
        techId: currentTechId,
        techName: techName,
        bidAmount: amount,
        proposalNote: 'Accepted customer offer of AED ${amount.toStringAsFixed(0)}',
        senderRole: 'tech',
        senderName: techName,
        status: 'accepted',
      );

      await dbService.updateBidStatus(
        bookingId: targetRequestId,
        techId: currentTechId,
        customerId: '',
        bidId: 'accepted',
        status: 'accepted',
        notes: 'Tech accepted customer counter-bid of AED ${amount.toStringAsFixed(0)}',
        senderRole: 'tech',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accepted customer offer of AED ${amount.toStringAsFixed(0)}!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting bid: $e')),
      );
    }
  }

  Future<void> _declineCustomerBid(String techId, String targetRequestId) async {
    setState(() => _isSubmitting = true);
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final currentTechId = authUser?.uid ?? prefs.getString('phoneNumber') ?? prefs.getString('email') ?? techId;
      final techName = authUser?.displayName ?? prefs.getString('firstName') ?? prefs.getString('tech_firstName') ?? 'Technician';
      final dbService = ref.read(databaseServiceProvider);

      await dbService.submitBid(
        bookingId: targetRequestId,
        techId: currentTechId,
        techName: techName,
        bidAmount: 0.0,
        proposalNote: 'Technician declined counter-bid',
        senderRole: 'tech',
        senderName: techName,
        status: 'declined',
      );

      await dbService.updateBidStatus(
        bookingId: targetRequestId,
        techId: currentTechId,
        customerId: '',
        bidId: 'declined',
        status: 'declined',
        notes: 'Technician declined customer counter-bid',
        senderRole: 'tech',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Counter-bid declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining bid: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFECEEF1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                ),
                child: FutureBuilder<String>(
                  future: _getTargetRequestId(),
                  builder: (context, snapshot) {
                    final targetRequestId = snapshot.data ?? 'demo_request_id';
                    return _buildRealtimeBidsTopSection(targetRequestId);
                  },
                ),
              ),
              _buildCustomKeypad(),
              const SizedBox(height: 4),
              Container(
                width: 140,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealtimeBidsTopSection(String targetRequestId) {
    final currentTechId = _currentTechId.isNotEmpty ? _currentTechId : 'tech_demo';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Realtime Bid Negotiation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (_stage == _BidStage.waiting)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _stage = _BidStage.entering;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Bid Again',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: currentTechId.isNotEmpty && targetRequestId.isNotEmpty
              ? FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collection('techs').doc(currentTechId).collection('requests').doc(targetRequestId).snapshots()
              : const Stream.empty(),
          builder: (context, reqSnapshot) {
            final reqData = reqSnapshot.data?.data();
            final reqStatus = reqData?['status'] as String? ?? 'pending';

            if (reqStatus == 'accepted' || reqStatus == 'in_progress') {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Task Accepted! Everything is updated automatically.',
                        style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Stream real-time bids for this booking
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ref.read(databaseServiceProvider).streamBidsForBooking(targetRequestId, techId: currentTechId),
          builder: (context, snapshot) {
            final rawDocs = snapshot.data?.docs ?? [];
            final cleanWId = targetRequestId.replaceAll('ID #', '').trim();

            final bidDocs = rawDocs.where((doc) {
              final data = doc.data();
              final bId = (data['bookingId'] as String? ?? '').replaceAll('ID #', '').trim();
              final rId = (data['requestId'] as String? ?? '').replaceAll('ID #', '').trim();
              final path = doc.reference.path;

              return targetRequestId.isEmpty ||
                  cleanWId.isEmpty ||
                  bId == targetRequestId ||
                  rId == targetRequestId ||
                  bId == cleanWId ||
                  rId == cleanWId ||
                  bId.toLowerCase() == cleanWId.toLowerCase() ||
                  rId.toLowerCase() == cleanWId.toLowerCase() ||
                  path.contains(targetRequestId) ||
                  path.contains(cleanWId);
            }).toList();

            bidDocs.sort((a, b) {
              final tsA = a.data()['createdAt'] ?? a.data()['timestamp'] ?? a.data()['updatedAt'];
              final tsB = b.data()['createdAt'] ?? b.data()['timestamp'] ?? b.data()['updatedAt'];
              if (tsA is Timestamp && tsB is Timestamp) {
                return tsA.compareTo(tsB);
              }
              return 0;
            });

            if (bidDocs.isNotEmpty) {
              final latestBidData = bidDocs.last.data();
              final latestSenderRole = latestBidData['senderRole'] as String? ?? 'tech';
              final latestAmount = (latestBidData['amount'] as num?)?.toDouble() ?? (latestBidData['price'] as num?)?.toDouble() ?? 0.0;
              final latestStatus = latestBidData['status'] as String? ?? 'pending';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latest Status:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    if (latestStatus == 'accepted')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Accepted Offer',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Accepted AED ${latestAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (latestStatus == 'declined')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Icon(Icons.cancel, color: Color(0xFFEF4444), size: 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text('Counter-Bid Declined', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      )
                    else if (latestSenderRole == 'customer')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Counter-Bid: AED ${latestAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : () => _acceptCustomerBid(latestAmount, currentTechId, targetRequestId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : () => _declineCustomerBid(currentTechId, targetRequestId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Text(
                        'Your offer of AED ${latestAmount.toStringAsFixed(0)} sent to customer. Awaiting response...',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        const Text(
          'Enter bid amount',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E4E8), width: 1.2),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            _enteredAmount.isEmpty ? 'Your offer' : '$_enteredAmount AED',
            style: TextStyle(
              color: _enteredAmount.isEmpty ? const Color(0xFFA0A3AA) : Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_enteredAmount.isNotEmpty && !_isSubmitting) ? _sendBid : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.black54,
              disabledForegroundColor: Colors.white70,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text(
                    'Send Bid',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomKeypad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              _buildKey('1', ''),
              _buildKey('2', 'ABC'),
              _buildKey('3', 'DEF'),
            ],
          ),
          Row(
            children: [
              _buildKey('4', 'GHI'),
              _buildKey('5', 'JKL'),
              _buildKey('6', 'MNO'),
            ],
          ),
          Row(
            children: [
              _buildKey('7', 'PQRS'),
              _buildKey('8', 'TUV'),
              _buildKey('9', 'WXYZ'),
            ],
          ),
          Row(
            children: [
              const Expanded(child: SizedBox(height: 46)),
              _buildKey('0', ''),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3.5),
                  child: SizedBox(
                    height: 46,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _onBackspace,
                        borderRadius: BorderRadius.circular(10),
                        child: const Center(
                          child: Icon(
                            Icons.backspace_outlined,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String number, String letters) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3.5),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _onKeyPressed(number),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    number,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                  if (letters.isNotEmpty)
                    Text(
                      letters,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: Colors.black,
                        height: 1.0,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

