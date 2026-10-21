import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'task_description_screen.dart';
import 'tech_notification_screen.dart';
import 'tech_main_layout.dart';
import '../../widgets/request_card.dart';
import '../../widgets/notification_bell_button.dart';
import '../../providers/booking_provider.dart';

class TechRequestsScreen extends ConsumerStatefulWidget {
  final String? initialFilter;
  final bool embedInShell;

  const TechRequestsScreen({
    super.key,
    this.initialFilter,
    this.embedInShell = false,
  });

  @override
  ConsumerState<TechRequestsScreen> createState() => _TechRequestsScreenState();
}

class _TechRequestsScreenState extends ConsumerState<TechRequestsScreen> {
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

  // --- STREAM BOOKINGS FROM RIVERPAD ---
  Widget _buildBookingsStream() {
    final bookingsAsync = ref.watch(techAssignedBookingsProvider);

    return bookingsAsync.when(
      data: (bookings) {
        final filterCode = _currentFilterCode;
        final filteredList = bookings.where((booking) {
          final status = booking.status.toLowerCase();
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

        if (filteredList.isEmpty) {
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
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredList.length,
          itemBuilder: (context, index) {
            final booking = filteredList[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: RequestCard(
                requestId: booking.id,
                customerName: booking.customerName.isNotEmpty ? booking.customerName : 'Customer',
                serviceName: booking.serviceTitle,
                location: booking.address,
                description: booking.description.isNotEmpty ? booking.description : 'Service Request',
                serviceImageUrl: 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=500&auto=format&fit=crop&q=60',
                badgeText: booking.status == 'completed'
                    ? 'Completed'
                    : ((booking.status == 'cancelled' || booking.status == 'declined' || booking.status == 'rejected')
                        ? 'Cancelled'
                        : (booking.status == 'pending_customer_confirmation'
                            ? 'Pending Confirmation'
                            : 'In Progress')),
                dateText: booking.date.isNotEmpty ? booking.date : 'Today',
                timeText: booking.time.isNotEmpty ? booking.time : 'Now',
                onView: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDescriptionScreen(
                        requestId: booking.id,
                        initialIndex: 1,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: Colors.black),
        ),
      ),
      error: (err, _) => Center(
        child: Text('Error loading requests: $err', style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}
