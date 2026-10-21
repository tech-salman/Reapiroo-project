import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/notification_provider.dart';
import '../../widgets/notification_card.dart';

class CustomerNotificationScreen extends ConsumerStatefulWidget {
  const CustomerNotificationScreen({super.key});

  @override
  ConsumerState<CustomerNotificationScreen> createState() => _CustomerNotificationScreenState();
}

class _CustomerNotificationScreenState extends ConsumerState<CustomerNotificationScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsStreamProvider);
    final notifications = notifsAsync.asData?.value ?? [];

    final filteredList = notifications.where((n) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Orders') {
        return n.type == 'booking' || n.type == 'bid';
      }
      return n.type == _selectedFilter.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final controller = ref.read(notificationControllerProvider.notifier);
                      for (var n in notifications) {
                        if (!n.isRead) {
                          await controller.markNotificationRead(n.id);
                        }
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All notifications marked as read.')),
                        );
                      }
                    },
                    child: const Text(
                      'Read all',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter Pills
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: ['All', 'Orders', 'Promos'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.black : const Color(0xFFE5E5EA),
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // Notifications List
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Text(
                        'No notifications',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        final isBooking = item.type == 'booking' || item.type == 'bid';
                        return NotificationCard(
                          title: item.title,
                          message: item.description,
                          time: item.time,
                          icon: isBooking ? Icons.check_circle_rounded : Icons.notifications_rounded,
                          iconColor: const Color(0xFF2F80ED),
                          isRead: item.isRead,
                          onTap: () {
                            ref.read(notificationControllerProvider.notifier).markNotificationRead(item.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
