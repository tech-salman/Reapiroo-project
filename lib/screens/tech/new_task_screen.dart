import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/providers/services_providers.dart';
import 'package:reapiroo/services/permission_service.dart';
import 'package:reapiroo/services/storage_service.dart';
import 'package:reapiroo/services/chat_service.dart';
import 'package:reapiroo/screens/tech/tech_main_layout.dart';
import 'package:reapiroo/screens/tech/tech_requests_screen.dart';
import 'package:reapiroo/screens/tech/tech_chat_screen.dart';
import 'package:reapiroo/widgets/custom_bottom_nav_bar.dart';
import 'package:reapiroo/widgets/new_task_card.dart';

class NewTaskScreen extends ConsumerStatefulWidget {
  final String? requestId;
  final String serviceName;

  const NewTaskScreen({
    super.key,
    this.requestId,
    this.serviceName = 'Plumbing',
  });

  @override
  ConsumerState<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends ConsumerState<NewTaskScreen> {
  int _currentNavIndex = 0;
  String _currentTechId = '';

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final uid = await ChatService.getEffectiveUserId();
    if (mounted) setState(() => _currentTechId = uid);
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

  static const List<CustomNavItem> _navItems = [
    CustomNavItem(icon: Icons.home, label: 'Home'),
    CustomNavItem(icon: Icons.calendar_month_outlined, label: 'Requests'),
    CustomNavItem(icon: Icons.chat_bubble_rounded, label: 'Chat'),
    CustomNavItem(icon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _requestStream(),
      builder: (context, requestSnap) {
        final reqData = requestSnap.data?.data() ?? {};
        final status = (reqData['status'] as String? ?? 'open').toLowerCase();
        
        final customerName = reqData['customerName'] as String? ?? 'Customer';
        final serviceName = reqData['title'] as String? ?? reqData['serviceName'] as String? ?? widget.serviceName;
        final location = reqData['address'] as String? ?? reqData['location'] as String? ?? 'Location';
        final description = reqData['description'] as String? ?? 'No description provided.';
        final serviceImageUrl = reqData['serviceImageUrl'] as String? ?? '';
        final sparePartImageUrl = reqData['sparePartImageUrl'] as String?;
        final voiceNoteUrl = reqData['voiceNoteUrl'] as String? ?? reqData['audioUrl'] as String?;
        final needSpareParts = (reqData['needSpareParts'] as bool?) ?? (sparePartImageUrl != null && sparePartImageUrl.trim().isNotEmpty);
        final List<String> mediaUrls = reqData['mediaUrls'] != null && reqData['mediaUrls'] is List
            ? List<String>.from(reqData['mediaUrls'])
            : [];
        final date = reqData['date'] as String? ?? 'Mon, Dec 23';
        final time = reqData['time'] as String? ?? '12:00';

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.requestId != null && widget.requestId!.isNotEmpty
              ? ref.read(databaseServiceProvider).streamBidsForBooking(widget.requestId!, techId: _currentTechId.isNotEmpty ? _currentTechId : null)
              : const Stream.empty(),
          builder: (context, bidsSnapshot) {
            bool hasAcceptedBid = false;
            final bidDocs = bidsSnapshot.data?.docs ?? [];
            for (final doc in bidDocs) {
              final bData = doc.data();
              final bStatus = (bData['status'] as String? ?? '').toLowerCase();
              if (bStatus == 'accepted') {
                hasAcceptedBid = true;
                break;
              }
            }

            final bool isCustomerAccepted = status == 'accepted' ||
                status == 'booked' ||
                status == 'in_progress' ||
                status == 'bid_accepted' ||
                hasAcceptedBid;

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
                            serviceName,
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
                                NewTaskCard(
                                  customerName: customerName,
                                  requestId: widget.requestId,
                                  location: location,
                                  description: description,
                                  serviceImageUrl: serviceImageUrl,
                                  mediaUrls: mediaUrls,
                                  sparePartImageUrl: sparePartImageUrl,
                                  voiceNoteUrl: voiceNoteUrl,
                                  serviceName: serviceName,
                                  date: date,
                                  time: time,
                                  hasSpareParts: needSpareParts,
                                  onSparePartsPressed: () => _showSparePartsDialog(context, sparePartImageUrl),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: _buildBottomActionButtons(status, isCustomerAccepted),
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
                          if (index == 0) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const TechMainLayout()),
                            );
                          } else if (index == 1) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const TechRequestsScreen()),
                            );
                          } else if (index == 2) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const TechChatScreen()),
                            );
                          } else {
                            setState(() {
                              _currentNavIndex = index;
                            });
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
          'New Task',
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
        final reqData = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collection('techs').doc(_currentTechId).collection('requests').doc(widget.requestId!).get();
        final customerId = reqData.data()?['customerId'] as String? ?? reqData.data()?['userId'] as String? ?? '';
        final serviceName = reqData.data()?['title'] as String? ?? widget.serviceName;
        if (customerId.isNotEmpty) {
          await dbService.addNotification(
            recipientId: customerId,
            title: 'Task Completion Pending Confirmation',
            description: 'The technician has marked "$serviceName" as done. Please review and confirm the task is completed.',
            type: 'task_confirmation',
            targetId: widget.requestId!,
            isTech: false,
          );
        }
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task marked as done! Waiting for customer confirmation.'),
        backgroundColor: Colors.black,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const TechRequestsScreen(initialFilter: 'In Progress')),
      (route) => false,
    );
  }

  Widget _buildBottomActionButtons(String status, bool isCustomerAccepted) {
    final s = status.toLowerCase();
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

    if (isCustomerAccepted) {
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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => _showCancelDialog(context),
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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
                'Bid',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => _showCancelDialog(context),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSparePartsDialog(BuildContext context, String? sparePartImageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return _SparePartsDialog(sparePartImageUrl: sparePartImageUrl);
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
          serviceName: widget.serviceName,
        );
      },
    );
  }

  void _showCancelDialog(BuildContext context) {
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
                            if (widget.requestId != null && widget.requestId!.isNotEmpty) {
                              try {
                                await ref.read(databaseServiceProvider).updateRequestStatus(widget.requestId!, 'cancelled');
                              } catch (_) {}
                            }
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const TechMainLayout()),
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
                            Navigator.pop(context);
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
}

class _SparePartsDialog extends StatefulWidget {
  final String? sparePartImageUrl;
  const _SparePartsDialog({this.sparePartImageUrl});

  @override
  State<_SparePartsDialog> createState() => _SparePartsDialogState();
}

class _SparePartsDialogState extends State<_SparePartsDialog> {
  bool _hasBought = false;
  String? _invoiceImagePath;
  final TextEditingController _amountController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickInvoice() async {
    final bool hasPermission = await PermissionService.requestMediaPermission(
      context,
      reason: 'Photo access is required to select and upload invoice receipts.',
    );
    if (!hasPermission) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _invoiceImagePath = image.path;
      });
    }
  }

  bool get _isDoneEnabled {
    if (!_hasBought) return true;
    return _invoiceImagePath != null && _amountController.text.trim().isNotEmpty;
  }

  void _showZoomableImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                InteractiveViewer(
                  panEnabled: true,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image(
                        image: StorageService.getImageProvider(imageUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxDialogHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Spare Parts',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.sparePartImageUrl != null && widget.sparePartImageUrl!.trim().isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _showZoomableImage(context, widget.sparePartImageUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image(
                      image: StorageService.getImageProvider(widget.sparePartImageUrl!),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 160,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image, color: Colors.black45, size: 40),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: const Text(
                    'No spare parts image provided by customer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Have you bought it?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB5B5B8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _hasBought = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _hasBought ? Colors.black : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Yes',
                              style: TextStyle(
                                color: _hasBought ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _hasBought = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: !_hasBought ? Colors.black : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'No',
                              style: TextStyle(
                                color: !_hasBought ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_hasBought) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Invoice of spare part',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _invoiceImagePath != null
                                ? 'Invoice uploaded successfully'
                                : 'Upload the invoice as a proof of your purchase',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _invoiceImagePath != null ? Colors.green : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _pickInvoice,
                      icon: Icon(
                        _invoiceImagePath != null ? Icons.check_circle : Icons.arrow_upward_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      label: Text(
                        _invoiceImagePath != null ? 'Uploaded' : 'Upload',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _invoiceImagePath != null ? Colors.green : Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_invoiceImagePath != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showZoomableImage(context, _invoiceImagePath!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image(
                        image: StorageService.getImageProvider(_invoiceImagePath!),
                        height: 70,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E4E8), width: 1.2),
                  ),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter Amount',
                      hintStyle: TextStyle(
                        color: Color(0xFFA0A3AA),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isDoneEnabled
                            ? () {
                                Navigator.pop(context);
                                if (_hasBought) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Spare parts details saved (${_amountController.text.trim()} AED)'),
                                      backgroundColor: Colors.black,
                                    ),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDoneEnabled ? Colors.black : Colors.grey.shade300,
                          foregroundColor: _isDoneEnabled ? Colors.white : Colors.grey.shade600,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0E0E2),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFB0B0B4), width: 1.2),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text('Offer Accepted by Customer!', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 13)),
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
