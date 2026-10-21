import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reapiroo/providers/services_providers.dart';
import 'package:reapiroo/widgets/custom_bottom_nav_bar.dart';
import 'package:reapiroo/screens/customer/customer_main_layout.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/services/storage_service.dart';
import 'package:reapiroo/services/chat_service.dart';
import 'package:reapiroo/widgets/offer_card.dart';

class CustomerOffersScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String serviceName;
  final bool embedInShell;

  const CustomerOffersScreen({
    super.key,
    required this.requestId,
    this.serviceName = 'Plumbing',
    this.embedInShell = false,
  });

  @override
  ConsumerState<CustomerOffersScreen> createState() => _CustomerOffersScreenState();
}

class _CustomerOffersScreenState extends ConsumerState<CustomerOffersScreen> {
  String _selectedSort = 'Lowest price';
  final int _currentNavIndex = 0; // Home tab
  Map<String, dynamic>? _selectedTechOffer;

  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final uid = await ChatService.getEffectiveUserId();
    setState(() => _currentUserId = uid);
  }

  static const List<CustomNavItem> _navItems = [
    CustomNavItem(icon: Icons.home, label: 'Home'),
    CustomNavItem(customIcon: RequestsCalendarIcon(), icon: Icons.calendar_today, label: 'Bookings'),
    CustomNavItem(customIcon: ChatBubblesIcon(), icon: Icons.chat_bubble, label: 'Chat'),
    CustomNavItem(customIcon: ProfileBustIcon(), icon: Icons.person, label: 'Profile'),
  ];

  Future<void> _handleAcceptOffer(Map<String, dynamic> offer) async {
    final price = (offer['price'] as num?)?.toDouble() ?? (offer['amount'] as num?)?.toDouble() ?? (offer['bidAmount'] as num?)?.toDouble() ?? 150.0;

    setState(() {
      offer['status'] = 'accepted';
      if (_selectedTechOffer != null) {
        _selectedTechOffer!['status'] = 'accepted';
      }
    });

    if (!mounted) return;
    _showPaymentPopup(price, offer);
  }

  void _showPaymentPopup(double effectivePrice, Map<String, dynamic> offer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      effectivePrice.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'AED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              _buildPaymentMethodButton(
                icon: Icons.account_balance_wallet,
                label: 'Pay via Wallet',
                onTap: () => _processFinalPayment(effectivePrice, 'Wallet', offer, dialogContext),
              ),
              const SizedBox(height: 12),
              _buildPaymentMethodButton(
                icon: Icons.credit_card,
                label: 'Pay via Card',
                onTap: () => _processFinalPayment(effectivePrice, 'Card', offer, dialogContext),
              ),
              const SizedBox(height: 12),
              _buildPaymentMethodButton(
                icon: Icons.apple,
                label: 'Apple Pay',
                onTap: () => _processFinalPayment(effectivePrice, 'Apple Pay', offer, dialogContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _processFinalPayment(double amount, String method, Map<String, dynamic> offer, BuildContext dialogContext) async {
    Navigator.pop(dialogContext);

    final offerId = offer['bidId'] as String? ?? offer['offerId'] as String? ?? offer['id'] as String? ?? '';
    final techId = offer['techId'] as String? ?? offer['technicianId'] as String? ?? '';

    final dbService = ref.read(databaseServiceProvider);
    if (method == 'Wallet') {
      try {
        final custDoc = await dbService.getCustomerProfile(_currentUserId);
        final availableBalance = (custDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

        if (availableBalance < amount) {
          if (!mounted) return;
          _showPaymentFailedDialog(availableBalance, amount);
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking wallet balance: $e')),
        );
        return;
      }
    }

    try {
      await dbService.acceptBid(
        customerId: _currentUserId,
        bookingId: widget.requestId,
        bidId: offerId,
        techId: techId,
        amount: amount,
      );

      if (!mounted) return;
      _showPaymentSuccessDialog(amount, method);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment/Acceptance error: $e')),
      );
    }
  }

  void _showPaymentFailedDialog(double availableBalance, double requiredAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Payment Not Done',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Payment is not done due to not enough balance in your wallet.\n\nAvailable Balance: AED ${availableBalance.toStringAsFixed(2)}\nRequired Amount: AED ${requiredAmount.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentSuccessDialog(double amount, String method) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Payment Done',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Payment of AED ${amount.toStringAsFixed(2)} completed successfully via $method!\nYour job has been successfully booked.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const CustomerMainLayout(initialIndex: 1)),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View Bookings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getOffersStream() {
    final cleanWId = widget.requestId.replaceAll('ID #', '').trim();
    if (_currentUserId.isNotEmpty && cleanWId.isNotEmpty) {
      return ref.read(databaseServiceProvider).customerBidsCollection(_currentUserId, cleanWId).snapshots();
    }
    return Stream.empty();
  }

  /// Real-Time Continuous 2-Way Bidding Bottom Sheet Modal
  void _showBidBottomSheet(Map<String, dynamic> offer) {
    final TextEditingController bidController = TextEditingController();
    final techName = offer['techName'] as String? ?? offer['technicianName'] as String? ?? 'Technician';
    final offerTechId = offer['techId'] as String? ?? offer['technicianId'] as String? ?? 'tech_demo';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Live Bidding with $techName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: _currentUserId.isEmpty 
                        ? const Center(child: CircularProgressIndicator(color: Colors.black))
                        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: ref.read(databaseServiceProvider).streamBidsForBooking(widget.requestId, customerId: _currentUserId),
                      builder: (context, snapshot) {
                        final rawDocs = snapshot.data?.docs ?? [];
                        final cleanWId = widget.requestId.replaceAll('ID #', '').trim();

                        final bidDocs = rawDocs.where((doc) {
                          final data = doc.data();
                          final bId = (data['bookingId'] as String? ?? '').replaceAll('ID #', '').trim();
                          final rId = (data['requestId'] as String? ?? '').replaceAll('ID #', '').trim();
                          final tId = (data['techId'] as String? ?? '').trim();
                          final path = doc.reference.path;

                          bool matchesReq = widget.requestId.isEmpty ||
                              cleanWId.isEmpty ||
                              bId == widget.requestId ||
                              rId == widget.requestId ||
                              bId == cleanWId ||
                              rId == cleanWId ||
                              bId.toLowerCase() == cleanWId.toLowerCase() ||
                              rId.toLowerCase() == cleanWId.toLowerCase() ||
                              path.contains(widget.requestId) ||
                              path.contains(cleanWId);

                          bool matchesTech = offerTechId.isEmpty ||
                              tId == offerTechId ||
                              tId.isEmpty ||
                              offerTechId == 'tech_demo';

                          return matchesReq && matchesTech;
                        }).toList();

                        // Sort bids chronologically by timestamp
                        bidDocs.sort((a, b) {
                          final tsA = a.data()['createdAt'] ?? a.data()['timestamp'] ?? a.data()['updatedAt'];
                          final tsB = b.data()['createdAt'] ?? b.data()['timestamp'] ?? b.data()['updatedAt'];
                          if (tsA is Timestamp && tsB is Timestamp) {
                            return tsA.compareTo(tsB);
                          }
                          return 0;
                        });

                        if (bidDocs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.gavel_outlined, size: 36, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'Place a counter-bid for $techName',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }

                        final bids = bidDocs.map((d) => d.data()).toList();
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: bids.length,
                          itemBuilder: (context, index) {
                            final b = bids[index];
                            final senderRole = b['senderRole'] as String? ?? 'tech';
                            final senderName = b['senderName'] as String? ?? (senderRole == 'customer' ? 'You' : techName);
                            final amount = (b['amount'] as num?)?.toDouble() ?? (b['price'] as num?)?.toDouble() ?? 0.0;
                            final notes = b['notes'] as String? ?? b['proposalNote'] as String? ?? '';
                            final status = b['status'] as String? ?? 'pending';
                            final isMe = senderRole == 'customer';

                            if (status == 'accepted') {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(16),
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
                                            'Accepted AED ${amount.toStringAsFixed(0)}',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: status == 'accepted'
                                      ? (isMe ? const Color(0xFF10B981) : const Color(0xFFD1FAE5))
                                      : status == 'declined'
                                          ? (isMe ? const Color(0xFFEF4444) : const Color(0xFFFEE2E2))
                                          : (isMe ? Colors.black : const Color(0xFFF0F0F4)),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isMe ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'AED ${amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: isMe ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    if (notes.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        notes,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isMe ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                    if (status != 'pending') ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        status == 'accepted' ? '✓ Accepted' : '✗ Declined',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isMe ? Colors.white : (status == 'accepted' ? const Color(0xFF047857) : const Color(0xFFB91C1C)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Enter your counter-bid amount',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: bidController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      decoration: const InputDecoration(
                        hintText: 'e.g. 120 AED',
                        hintStyle: TextStyle(color: Colors.black38, fontSize: 15, fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final text = bidController.text.trim();
                              final amount = double.tryParse(text);
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid bid amount.')),
                                );
                                return;
                              }

                              setSheetState(() => isSubmitting = true);

                              try {
                                await ref.read(databaseServiceProvider).submitBid(
                                  bookingId: widget.requestId,
                                  techId: offerTechId,
                                  techName: techName,
                                  bidAmount: amount,
                                  proposalNote: 'Customer counter-bid: AED ${amount.toStringAsFixed(0)}',
                                  senderRole: 'customer',
                                  senderName: 'You',
                                );

                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Counter-bid of AED ${amount.toStringAsFixed(0)} sent to $techName!')),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSubmitting = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Error placing bid: $e')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Send Counter-Bid',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedTechOffer != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _buildTechnicianProfileView(_selectedTechOffer!),
        ),
      );
    }

    if (!widget.embedInShell) {
      return Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildMainContent(),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: AnimatedCurvedNavBar(
                  items: _navItems,
                  currentIndex: _currentNavIndex,
                  onTap: (index) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => CustomerMainLayout(initialIndex: index)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildMainContent();
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Bar: Circular Back Button & Title (Matching Image 1)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.serviceName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Sub-header Row: "Searching Best offer" & Sort Dropdown Pill
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Searching Best offer',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSort,
                    isDense: true,
                    dropdownColor: Colors.black,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    items: ['Lowest price', 'Highest price']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSort = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Live Real-Time Offers Stream Builder from Firebase (Zero Fake Data)
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _getOffersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(color: Colors.grey.shade800, strokeWidth: 3),
                      ),
                      const SizedBox(height: 16),
                      const Text('Searching for nearby technicians...', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading offers: ${snapshot.error}', style: const TextStyle(color: Colors.grey)),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              final cleanWId = widget.requestId.replaceAll('ID #', '').trim();

              final filteredDocs = docs.where((doc) {
                final data = doc.data();
                final bId = (data['bookingId'] as String? ?? '').replaceAll('ID #', '').trim();
                final rId = (data['requestId'] as String? ?? '').replaceAll('ID #', '').trim();
                final path = doc.reference.path;

                if (widget.requestId.isNotEmpty) {
                  return bId == widget.requestId ||
                      rId == widget.requestId ||
                      bId == cleanWId ||
                      rId == cleanWId ||
                      bId.toLowerCase() == cleanWId.toLowerCase() ||
                      rId.toLowerCase() == cleanWId.toLowerCase() ||
                      path.contains(widget.requestId) ||
                      (cleanWId.isNotEmpty && path.contains(cleanWId));
                }
                return true;
              }).toList();

              final activeDocs = filteredDocs;

              // Deduplicate/Group by technician ID to show latest active offer per technician
              final Map<String, Map<String, dynamic>> latestOffersByTech = {};
              for (var doc in activeDocs) {
                final data = doc.data();
                final techId = data['techId'] as String? ?? data['offerId'] as String? ?? doc.id;
                if (!latestOffersByTech.containsKey(techId)) {
                  latestOffersByTech[techId] = data;
                } else {
                  final existing = latestOffersByTech[techId]!;
                  final existingTs = existing['createdAt'] ?? existing['timestamp'] ?? existing['updatedAt'];
                  final newTs = data['createdAt'] ?? data['timestamp'] ?? data['updatedAt'];
                  if (newTs != null && (existingTs == null || (newTs is Timestamp && existingTs is Timestamp && newTs.compareTo(existingTs) > 0))) {
                    latestOffersByTech[techId] = data;
                  }
                }
              }

              var offersList = latestOffersByTech.values.toList();
              if (_selectedSort == 'Lowest price') {
                offersList.sort((a, b) => ((a['price'] as num?) ?? 0).compareTo((b['price'] as num?) ?? 0));
              } else {
                offersList.sort((a, b) => ((b['price'] as num?) ?? 0).compareTo((a['price'] as num?) ?? 0));
              }

              return Column(
                children: [
                  Expanded(
                    child: offersList.isNotEmpty
                        ? ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: offersList.length,
                            itemBuilder: (context, index) {
                              return OfferCard(
                                offer: offersList[index],
                                onTap: () {
                                  setState(() {
                                    _selectedTechOffer = offersList[index];
                                  });
                                },
                                onAccept: () => _handleAcceptOffer(offersList[index]),
                                onBid: () => _showBidBottomSheet(offersList[index]),
                              );
                            },
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: CircularProgressIndicator(color: Colors.grey.shade800, strokeWidth: 3),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Finding Best offer...',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Waiting for nearby technicians to submit bids.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                  ),

                  // Bottom Full-Width Cancel Button (Matching Image 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 85.0, top: 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => Navigator.maybePop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Black Technician Offer Card (Pixel Perfect Matching Image 1)
  Widget _buildTechnicianProfileView(Map<String, dynamic> offer) {
    final techId = offer['techId'] as String? ?? offer['offerId'] as String? ?? '';
    final techName = offer['techName'] as String? ?? 'Technician';
    final experience = offer['experience'] as String? ?? 'Verified Technician';
    final price = (offer['price'] as num?)?.toDouble() ?? 0.0;
    final rating = (offer['rating'] as num?)?.toDouble() ?? 5.0;
    final reviewCount = (offer['reviewCount'] as num?)?.toInt() ?? 0;
    final avatarUrl = offer['avatarUrl'] as String? ?? offer['techAvatar'] as String? ?? '';
    final status = offer['status'] as String? ?? 'pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Bar with Back Arrow and Technician Name
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedTechOffer = null),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  techName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Technician Profile Card Header
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image(
                        image: StorageService.getImageProvider(avatarUrl),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.person, color: Colors.black54, size: 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            techName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            experience,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                price.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'AED',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Black Rating Banner (Matching Image 3)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFFC107), size: 28),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Color(0xFFFFC107), size: 28),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Color(0xFFFFC107), size: 28),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Color(0xFFFFC107), size: 28),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_border, color: Colors.white, size: 28),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${rating.toStringAsFixed(0)} out of 5',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$reviewCount reviews',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Real Customer Reviews Future Builder from Firebase Firestore
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: DatabaseService().fetchTechReviews(techId),
                  builder: (context, snapshot) {
                    final reviews = snapshot.data ?? [];
                    if (reviews.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.rate_review_outlined, color: Colors.grey, size: 36),
                            SizedBox(height: 8),
                            Text(
                              'No reviews yet for this technician',
                              style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reviews.length,
                        separatorBuilder: (context, index) => const Divider(height: 24, color: Colors.black12),
                        itemBuilder: (context, index) {
                          final r = reviews[index];
                          final reviewerName = r['userName'] as String? ?? r['name'] as String? ?? 'Customer';
                          final text = r['comment'] as String? ?? r['text'] as String? ?? 'Great service.';
                          final dateStr = r['dateText'] as String? ?? r['date'] as String? ?? 'Recently';
                          final revAvatar = r['userAvatar'] as String? ?? r['avatarUrl'] as String? ?? '';

                          return _buildReviewItem(
                            name: reviewerName,
                            date: dateStr,
                            text: text,
                            avatarUrl: revAvatar,
                          );
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Bottom Action Buttons: Accept to pay (or Accept & Bid)
                status == 'accepted'
                    ? SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => _handleAcceptOffer(offer),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () => _handleAcceptOffer(offer),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Accept',
                                  style: TextStyle(
                                    color: Colors.white,
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
                                onPressed: () => _showBidBottomSheet(offer),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE5E5EA),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Bid',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem({
    required String name,
    required String date,
    required String text,
    String? avatarUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: StorageService.getImageProvider(avatarUrl),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                ),
                Row(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                        Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                        Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                        Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                        Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.35),
        ),
      ],
    );
  }
}
