import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationBellButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color iconColor;
  final Color backgroundColor;
  final bool isTech;

  const NotificationBellButton({
    super.key,
    required this.onPressed,
    this.iconColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.isTech = false,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _listenUnreadCount();
  }

  Future<void> _listenUnreadCount() async {
    FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collectionGroup('notifications').snapshots().listen((snap) {
      if (!mounted) return;
      int count = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final path = doc.reference.path;
        final isRead = data['isRead'] as bool? ?? false;

        if (!isRead) {
          if (widget.isTech && path.contains('techs')) {
            count++;
          } else if (!widget.isTech && path.contains('customers')) {
            count++;
          }
        }
      }
      if (mounted && _unreadCount != count) {
        setState(() {
          _unreadCount = count;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.notifications, color: widget.iconColor, size: 22),
            onPressed: widget.onPressed,
          ),
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF2F80ED),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
