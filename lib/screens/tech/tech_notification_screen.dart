import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/notification_provider.dart';
import '../../widgets/notification_card.dart';

class TechNotificationScreen extends ConsumerStatefulWidget {
  const TechNotificationScreen({super.key});

  @override
  ConsumerState<TechNotificationScreen> createState() => _TechNotificationScreenState();
}

class _TechNotificationScreenState extends ConsumerState<TechNotificationScreen> {
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
            // Header
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
                          const SnackBar(content: Text('All notifications marked as read')),
                        );
                      }
                    },
                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['All', 'Orders', 'System', 'Promos'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Main List
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No notifications found',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        final isBooking = item.type == 'booking' || item.type == 'bid';
                        final icon = isBooking ? Icons.calendar_month : Icons.notifications;
                        final iconColor = isBooking ? const Color(0xFF8B5CF6) : Colors.black;

                        return NotificationCard(
                          title: item.title,
                          message: item.description,
                          time: item.time,
                          icon: icon,
                          iconColor: iconColor,
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
