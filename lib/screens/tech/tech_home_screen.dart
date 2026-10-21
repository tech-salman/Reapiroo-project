import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/providers/services_providers.dart';
import 'package:reapiroo/widgets/notification_bell_button.dart';
import 'package:reapiroo/widgets/app_info_cards_scroll_view.dart';
import 'package:reapiroo/widgets/request_card.dart';
import 'package:reapiroo/screens/tech/tech_main_layout.dart';
import 'package:reapiroo/screens/tech/tech_wallet_screen.dart';
import 'package:reapiroo/screens/tech/tech_notification_screen.dart';
import 'package:reapiroo/screens/tech/task_description_screen.dart';

class TechHomeScreen extends ConsumerStatefulWidget {
  final bool embedInShell;

  const TechHomeScreen({
    super.key,
    this.embedInShell = false,
  });

  @override
  ConsumerState<TechHomeScreen> createState() => _TechHomeScreenState();
}

class _TechHomeScreenState extends ConsumerState<TechHomeScreen> {
  bool _isAvailable = true;
  double _balance = 0.00;
  String _userName = 'Technician';
  String _userKey = '';
  StreamSubscription? _techProfileSub;

  final List<String> _services = [
    'All Services',
    'AC Repair',
    'AC Cleaning',
    'Plumber',
    'Electrician',
    'Carpenter',
    'Painter',
    'Appliances Repair',
    'Handyman',
    'Local Movers',
    'Water Tank Cleaning',
    'Cleaning',
    'Gardener',
    'Home Services / Maintenance',
  ];

  late String _selectedService;
  String _selectedSort = 'Nearest';

  @override
  void initState() {
    super.initState();
    _selectedService = _services[0]; // 'All Services'
    _loadTechUserData();
  }

  @override
  void dispose() {
    _techProfileSub?.cancel();
    super.dispose();
  }

  Future<void> _loadTechUserData() async {
    final authUser = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final key = authUser?.uid ?? prefs.getString('phoneNumber') ?? prefs.getString('email') ?? '';
    final dbService = ref.read(databaseServiceProvider);

    setState(() {
      _userKey = key;
      _userName = prefs.getString('firstName') ?? prefs.getString('tech_firstName') ?? 'Technician';
    });

    if (key.isNotEmpty) {
      _techProfileSub?.cancel();
      _techProfileSub = dbService.streamTechProfile(key).listen((snap) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          if (mounted) {
            setState(() {
              _userName = data['name'] as String? ?? _userName;
              _isAvailable = data['isAvailable'] as bool? ?? true;
              _balance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
            });
          }
        }
      });
    }
  }

  void _promptToggleAvailability(bool targetVal) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            targetVal ? 'Go Available?' : 'Go Offline?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            targetVal
                ? 'Enabling availability will allow you to receive new job requests from customers in real-time.'
                : 'Disabling availability will pause new incoming requests from customers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _applyAvailabilityChange(targetVal);
              },
              child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyAvailabilityChange(bool val) async {
    setState(() {
      _isAvailable = val;
    });
    if (_userKey.isNotEmpty) {
      await ref.read(databaseServiceProvider).updateTechAvailability(_userKey, val);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val ? 'You are now Available for new requests.' : 'You are now Offline.'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedInShell) {
      return const TechMainLayout(initialIndex: 0);
    }

    return Column(
      children: [
        // Fixed Header pinned above the scroll view
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: _buildHeader(),
        ),
        // Scrollable content underneath the static header
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 4.0,
              bottom: 120.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  'Hi $_userName',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                _buildBanner(),
                const SizedBox(height: 14),
                const AppInfoCardsScrollView(),
                const SizedBox(height: 14),
                _buildBalanceAvailabilityCard(),
                const SizedBox(height: 14),
                _buildFilterRow(),
                const SizedBox(height: 14),
                _buildActiveRequestsStream(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- TOP BAR ---
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
              icon: const Icon(Icons.menu, color: Colors.white, size: 24),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        const Spacer(),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            icon: const Icon(Icons.credit_card, color: Colors.white, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TechWalletScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        NotificationBellButton(
          isTech: true,
          backgroundColor: Colors.black,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TechNotificationScreen()),
            );
          },
        ),
      ],
    );
  }

  // --- BANNER ---
  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      height: 115,
      decoration: BoxDecoration(
        color: const Color(0xFF00B4D8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 190,
              child: Image.network(
                'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=60',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00A8E8),
                    const Color(0xFF00A8E8).withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 0.8],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              alignment: Alignment.centerLeft,
              child: const Text(
                'Ultimate Guide to\nApp Advertising',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BALANCE & AVAILABILITY ---
  Widget _buildBalanceAvailabilityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TechWalletScreen()),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card, size: 20, color: Colors.black),
                          SizedBox(width: 6),
                          Text(
                            'Balance',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_balance.toStringAsFixed(2)} AED',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E5EA)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Availability',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _promptToggleAvailability(!_isAvailable),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 26,
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: _isAvailable ? const Color(0xFF99E274) : Colors.grey.shade300,
                        ),
                        child: Align(
                          alignment: _isAvailable ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 21,
                            height: 21,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isAvailable ? const Color(0xFF00C814) : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FILTERS ---
  Widget _buildFilterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildServiceDropdown(),
        const SizedBox(width: 8),
        _buildSortDropdown(),
      ],
    );
  }

  Widget _buildServiceDropdown() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedService,
          isDense: true,
          dropdownColor: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          icon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
          ),
          selectedItemBuilder: (BuildContext context) {
            return _services.map<Widget>((String item) {
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList();
          },
          items: _services.map((String service) {
            return DropdownMenuItem<String>(
              value: service,
              child: Text(
                service,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedService = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSort,
          isDense: true,
          dropdownColor: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          icon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          items: const [
            DropdownMenuItem(value: 'Nearest', child: Text('Nearest')),
            DropdownMenuItem(value: 'Highest Rated', child: Text('Highest Rated')),
            DropdownMenuItem(value: 'Lowest Price', child: Text('Lowest Price')),
          ],
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedSort = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  // --- STREAM ACTIVE REQUESTS FROM FIREBASE ---
  Widget _buildActiveRequestsStream() {
    if (!_isAvailable) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: const Column(
          children: [
            Icon(Icons.power_settings_new, size: 40, color: Colors.orange),
            SizedBox(height: 8),
            Text(
              'You are Offline',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
            ),
            SizedBox(height: 4),
            Text(
              'Enable your availability to receive new job requests from customers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    if (_userKey.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.read(databaseServiceProvider).techRequestsCollection(_userKey).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: Colors.black),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> uniqueMap = {};
        for (final doc in docs) {
          final data = doc.data();
          final id = data['bookingId'] as String? ?? data['requestId'] as String? ?? data['id'] as String? ?? doc.id;
          uniqueMap[id] = doc;
        }

        final filteredDocs = uniqueMap.values.where((doc) {
          final data = doc.data();
          final status = (data['status'] as String? ?? 'open').toLowerCase();
          if (status == 'accepted' ||
              status == 'in_progress' ||
              status == 'booked' ||
              status == 'bid_accepted' ||
              status == 'pending_customer_confirmation' ||
              status == 'completed' ||
              status == 'cancelled' ||
              status == 'declined' ||
              status == 'rejected') {
            return false;
          }

          if (_selectedService == 'All Services') return true;
          final title = data['title'] as String? ?? '';
          final category = data['category'] as String? ?? data['serviceCategory'] as String? ?? '';
          return title.toLowerCase().contains(_selectedService.toLowerCase()) ||
              category.toLowerCase().contains(_selectedService.toLowerCase()) ||
              _selectedService.toLowerCase().contains(title.toLowerCase());
        }).toList();

        if (filteredDocs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            child: const Column(
              children: [
                Icon(Icons.inbox_outlined, size: 40, color: Colors.black38),
                SizedBox(height: 8),
                Text(
                  'No Job Requests Available',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                ),
                SizedBox(height: 4),
                Text(
                  'New customer service requests will appear here in real-time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          );
        }

        return Column(
          children: filteredDocs.map((doc) {
            final data = doc.data();
            final String rawId = (data['requestId'] as String? ??
                data['bookingId'] as String? ??
                data['id'] as String? ??
                '').trim();
            final String reqId = data['bookingId'] as String? ?? rawId;

            final custName = data['customerName'] as String? ?? 'Customer';
            final title = data['title'] as String? ?? 'Service';
            final location = data['address'] as String? ?? 'Downtown Road, Dubai';
            final desc = data['description'] as String? ?? '';
            final imgUrl = data['serviceImageUrl'] as String? ?? 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=500&auto=format&fit=crop&q=60';

            return Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: RequestCard(
                requestId: reqId,
                customerName: custName,
                serviceName: title,
                location: location,
                description: desc,
                serviceImageUrl: imgUrl,
                badgeText: 'New',
                dateText: 'Today, Now',
                timeText: '12:00',
                onView: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDescriptionScreen(
                        requestId: reqId,
                        initialIndex: 0,
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

}
