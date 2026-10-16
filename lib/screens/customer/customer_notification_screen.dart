import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/widgets/notification_card.dart';

class CustomerNotificationItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color iconColor;
  final String category; // 'Orders', 'Promos', 'System'
  final String dateGroup;
  bool isRead;

  CustomerNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.category,
    required this.dateGroup,
    this.isRead = false,
  });
}

class CustomerNotificationScreen extends StatefulWidget {
  const CustomerNotificationScreen({super.key});

  @override
  State<CustomerNotificationScreen> createState() => _CustomerNotificationScreenState();
}

class _CustomerNotificationScreenState extends State<CustomerNotificationScreen> {
  String _selectedFilter = 'All';
  List<CustomerNotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _listenNotifications();
  }

  Future<void> _listenNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> userCandidates = {};

    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.trim().isNotEmpty) {
      userCandidates.add(authUid.trim());
    }

    final phone = prefs.getString('phoneNumber') ?? prefs.getString('phone');
    if (phone != null && phone.trim().isNotEmpty) {
      final clean = phone.replaceAll(RegExp(r'\D'), '');
      userCandidates.add(clean);
      userCandidates.add('92$clean');
      if (clean.startsWith('92')) userCandidates.add(clean.substring(2));
    }

    final email = prefs.getString('email') ?? FirebaseAuth.instance.currentUser?.email;
    if (email != null && email.trim().isNotEmpty) {
      userCandidates.add(email.trim().toLowerCase());
    }

    final primaryId = userCandidates.isNotEmpty ? userCandidates.first : '';

    DatabaseService().streamUserNotifications(primaryId).listen((snap) {
      final loaded = snap.docs.where((doc) {
        final data = doc.data();
        final recipientId = data['recipientId'] as String? ?? data['userId'] as String? ?? '';
        final path = doc.reference.path;
        if (userCandidates.isNotEmpty) {
          return userCandidates.contains(recipientId) ||
              userCandidates.any((cand) => path.contains(cand));
        }
        return true;
      }).map((doc) {
        final data = doc.data();
        final type = data['type'] as String? ?? 'system';
        return CustomerNotificationItem(
          id: doc.id,
          title: data['title'] as String? ?? 'Notification',
          message: data['body'] as String? ?? data['description'] as String? ?? '',
          time: 'Recently',
          icon: type == 'booking' || type == 'bid' ? Icons.check_circle_rounded : Icons.notifications_rounded,
          iconColor: const Color(0xFF2F80ED),
          category: type == 'booking' || type == 'bid' ? 'Orders' : 'System',
          dateGroup: 'Today',
          isRead: data['isRead'] as bool? ?? false,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _notifications = loaded;
        });
      }
    });
  }

  List<CustomerNotificationItem> get _filteredNotifications {
    if (_selectedFilter == 'All') return _notifications;
    return _notifications.where((n) => n.category == _selectedFilter).toList();
  }

  void _markAllAsRead() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      for (var item in _notifications) {
        DatabaseService().markNotificationAsRead(uid, item.id);
      }
    }
    setState(() {
      for (var item in _notifications) {
        item.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredNotifications;

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
                    onPressed: _markAllAsRead,
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
              child: displayList.isEmpty
                  ? Center(
                      child: Text(
                        'No notifications',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final item = displayList[index];
                        return NotificationCard(
                          title: item.title,
                          message: item.message,
                          time: item.time,
                          icon: item.icon,
                          iconColor: item.iconColor,
                          isRead: item.isRead,
                          onTap: () {
                            setState(() {
                              item.isRead = true;
                            });
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
