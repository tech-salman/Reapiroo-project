import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/widgets/notification_card.dart';

class TechNotificationScreen extends StatefulWidget {
  const TechNotificationScreen({super.key});

  @override
  State<TechNotificationScreen> createState() => _TechNotificationScreenState();
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color iconColor;
  final String category; // 'Orders', 'System', 'Promos'
  final String dateGroup; // 'Today', 'Yesterday'
  bool isRead;

  NotificationItem({
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

class _TechNotificationScreenState extends State<TechNotificationScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _selectedFilter = 'All';
  List<NotificationItem> _notifications = [];
  StreamSubscription? _subscription;
  String _userKey = '';

  @override
  void initState() {
    super.initState();
    _listenNotifications();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _listenNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> userCandidates = {};

    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.trim().isNotEmpty) {
      userCandidates.add(authUid.trim());
      _userKey = authUid.trim();
    }

    final phone = prefs.getString('phoneNumber') ?? prefs.getString('phone');
    if (phone != null && phone.trim().isNotEmpty) {
      final clean = phone.replaceAll(RegExp(r'\D'), '');
      userCandidates.add(clean);
      userCandidates.add('92$clean');
      if (clean.startsWith('92')) userCandidates.add(clean.substring(2));
      if (_userKey.isEmpty) _userKey = clean;
    }

    final email = prefs.getString('email') ?? FirebaseAuth.instance.currentUser?.email;
    if (email != null && email.trim().isNotEmpty) {
      userCandidates.add(email.trim().toLowerCase());
      if (_userKey.isEmpty) _userKey = email.trim().toLowerCase();
    }

    try {
      final techIndexDoc = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collection('techs').doc('TECH_INDEX').get();
      if (techIndexDoc.exists) {
        final tIds = (techIndexDoc.data()?['techIds'] as List<dynamic>? ?? []).map((e) => e.toString());
        userCandidates.addAll(tIds);
        if (_userKey.isEmpty && tIds.isNotEmpty) _userKey = tIds.first;
      }
    } catch (_) {}

    userCandidates.add('tech_demo');
    if (_userKey.isEmpty) _userKey = 'tech_demo';

    _subscription = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collectionGroup('notifications').snapshots().listen((snap) {
      final loaded = snap.docs.where((doc) {
        final path = doc.reference.path;
        if (!path.contains('techs')) return false;
        return true;
      }).map((doc) {
        final data = doc.data();
        final type = data['type'] as String? ?? 'system';
        final title = data['title'] as String? ?? 'Notification';
        final message = data['body'] as String? ?? data['description'] as String? ?? data['message'] as String? ?? '';
        final isRead = data['isRead'] as bool? ?? false;

        IconData icon = Icons.notifications;
        Color iconColor = Colors.black;
        if (type == 'booking') {
          icon = Icons.calendar_month;
          iconColor = const Color(0xFF8B5CF6);
        } else if (type == 'wallet') {
          icon = Icons.account_balance_wallet;
          iconColor = const Color(0xFF10B981);
        }

        return NotificationItem(
          id: doc.id,
          title: title,
          message: message,
          time: 'Recently',
          icon: icon,
          iconColor: iconColor,
          category: type == 'booking' ? 'Orders' : 'System',
          dateGroup: 'Today',
          isRead: isRead,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _notifications = loaded;
        });
      }
    });
  }

  List<NotificationItem> get _filteredNotifications {
    if (_selectedFilter == 'All') return _notifications;
    return _notifications.where((n) => n.category == _selectedFilter).toList();
  }

  void _markAllAsRead() async {
    for (var item in _notifications) {
      if (_userKey.isNotEmpty) {
        await _dbService.markNotificationAsRead(_userKey, item.id, isTech: true);
      }
    }
    setState(() {
      for (var item in _notifications) {
        item.isRead = true;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredNotifications;

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
                    onPressed: _markAllAsRead,
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
              child: displayList.isEmpty
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
                            if (_userKey.isNotEmpty) {
                              _dbService.markNotificationAsRead(_userKey, item.id, isTech: true);
                            }
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
