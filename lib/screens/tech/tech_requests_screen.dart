import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reapiroo/screens/tech/task_description_screen.dart';
import 'package:reapiroo/screens/tech/tech_notification_screen.dart';
import 'package:reapiroo/screens/tech/tech_main_layout.dart';
import 'package:reapiroo/widgets/request_card.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/widgets/notification_bell_button.dart';

class TechRequestsScreen extends StatefulWidget {
  final String? initialFilter;
  final bool embedInShell;

  const TechRequestsScreen({
    super.key,
    this.initialFilter,
    this.embedInShell = false,
  });

  @override
  State<TechRequestsScreen> createState() => _TechRequestsScreenState();
}

class _TechRequestsScreenState extends State<TechRequestsScreen> {
  late String _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialFilter ?? 'In Progress';
  }

  String get _currentFilterCode {
    switch (_selectedStatusFilter) {
      case 'In Progress':
        return 'in_progress';
      case 'Completed':
        return 'completed';
      case 'Cancelled':
        return 'cancelled';
      default:
        return 'in_progress';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedInShell) {
      return const TechMainLayout(initialIndex: 1);
    }

    return Column(
      children: [
        // Top Header Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: _buildHeader(),
        ),

        // Title & Filter Dropdown Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              _buildStatusFilterDropdown(),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Request List or Empty Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 120.0,
            ),
            child: _buildBookingsStream(),
          ),
        ),
      ],
    );
  }

  // --- HEADER ---
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

  // --- FILTER DROPDOWN ---
  Widget _buildStatusFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
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

  Future<String> _getTechId() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && authUser.uid.isNotEmpty) {
      return authUser.uid;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('phoneNumber') ?? prefs.getString('email') ?? '';
  }

  // --- STREAM BOOKINGS FROM FIREBASE (ONLY ACCEPTED REQUESTS AFTER BID) ---
  Widget _buildBookingsStream() {
    return FutureBuilder<String>(
      future: _getTechId(),
      builder: (context, techIdSnap) {
        final currentTechId = techIdSnap.data ?? FirebaseAuth.instance.currentUser?.uid ?? '';

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: currentTechId.isNotEmpty 
              ? DatabaseService().techRequestsCollection(currentTechId).snapshots()
              : const Stream.empty(),
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
            final filteredDocs = docs.where((doc) {
              final data = doc.data();
              final status = (data['status'] as String? ?? 'open').toLowerCase();
              final bookedTechId = data['bookedTechId'] as String? ?? data['assignedTechnicianId'] as String? ?? '';

              // Match current technician ID if booked by a specific tech
              if (currentTechId.isNotEmpty && bookedTechId.isNotEmpty && bookedTechId != currentTechId && bookedTechId != 'tech_demo') {
                return false;
              }

              final filterCode = _currentFilterCode;
              if (filterCode == 'in_progress') {
                return status == 'accepted' ||
                    status == 'in_progress' ||
                    status == 'booked' ||
                    status == 'bid_accepted' ||
                    status == 'pending_customer_confirmation';
              } else if (filterCode == 'completed') {
                return status == 'completed';
              } else if (filterCode == 'cancelled') {
                return status == 'cancelled' || status == 'declined' || status == 'rejected';
              }
              return status == filterCode;
            }).toList();

            if (filteredDocs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9FB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.assignment_outlined, size: 44, color: Colors.black38),
                    const SizedBox(height: 10),
                    Text(
                      'No $_selectedStatusFilter Bookings',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bookings and requests updated in real-time will appear here.',
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
                final serviceName = data['title'] as String? ?? 'Service';
                final location = data['address'] as String? ?? 'Location';
                final desc = data['description'] as String? ?? '';
                final status = (data['status'] as String? ?? 'open').toLowerCase();
                final imgUrl = data['serviceImageUrl'] as String? ?? 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=500&auto=format&fit=crop&q=60';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14.0),
                  child: RequestCard(
                    requestId: reqId,
                    customerName: custName,
                    serviceName: serviceName,
                    location: location,
                    description: desc,
                    serviceImageUrl: imgUrl,
                    badgeText: status == 'completed'
                        ? 'Completed'
                        : ((status == 'cancelled' || status == 'declined' || status == 'rejected')
                            ? 'Cancelled'
                            : (status == 'pending_customer_confirmation'
                                ? 'Pending Confirmation'
                                : 'In Progress')),
                    dateText: 'Mon, Dec 23',
                    timeText: '12:00',
                    onView: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskDescriptionScreen(
                            requestId: reqId,
                            initialIndex: 1,
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
      },
    );
  }

}
