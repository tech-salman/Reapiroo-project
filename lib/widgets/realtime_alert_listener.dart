import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reapiroo/services/chat_service.dart';

class RealtimeAlertListener extends StatefulWidget {
  final Widget child;
  final bool isTech;

  const RealtimeAlertListener({
    super.key,
    required this.child,
    this.isTech = false,
  });

  @override
  State<RealtimeAlertListener> createState() => _RealtimeAlertListenerState();
}

class _RealtimeAlertListenerState extends State<RealtimeAlertListener> {
  StreamSubscription? _notifSub;
  StreamSubscription? _chatSub;
  final Set<String> _seenNotificationIds = {};
  final Set<String> _seenMessageIds = {};
  bool _isInitialNotificationLoad = true;
  bool _isInitialMessageLoad = true;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  @override
  void didUpdateWidget(covariant RealtimeAlertListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTech != widget.isTech) {
      _currentUserId = '';
      _initListeners();
    }
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _chatSub?.cancel();
    _notifSub = null;
    _chatSub = null;
    super.dispose();
  }

  Future<void> _initListeners() async {
    final userId = await ChatService.getEffectiveUserId();
    if (!mounted || userId.isEmpty || userId == 'demo_user') return;

    // Avoid creating new listeners if _currentUserId hasn't changed
    if (_currentUserId == userId && (_notifSub != null || _chatSub != null)) {
      return;
    }

    _notifSub?.cancel();
    _chatSub?.cancel();
    _notifSub = null;
    _chatSub = null;

    _currentUserId = userId;

    final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database');
    final rootCollection = widget.isTech ? 'techs' : 'customers';

    // 1. Listen to Realtime Notifications for current user
    _notifSub = db
        .collection(rootCollection)
        .doc(_currentUserId)
        .collection('notifications')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (_isInitialNotificationLoad) {
        for (final doc in snap.docs) {
          _seenNotificationIds.add(doc.id);
        }
        _isInitialNotificationLoad = false;
        return;
      }

      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final docId = change.doc.id;
          final data = change.doc.data();
          if (data == null) continue;

          final isRead = data['isRead'] as bool? ?? false;
          if (!isRead) {
            if (_seenNotificationIds.contains(docId)) continue;
            _seenNotificationIds.add(docId);

            final title = data['title'] as String? ?? 'New Notification';
            final body = data['body'] as String? ?? data['description'] as String? ?? '';
            _showAlertBanner(title, body, Icons.notifications_active, const Color(0xFF2F80ED));
          }
        }
      }
    });

    // 2. Listen to Realtime Chat Updates for current user
    _chatSub = db
        .collection(rootCollection)
        .doc(_currentUserId)
        .collection('chats')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (_isInitialMessageLoad) {
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data != null) {
            final lastMsgTime = data['lastMessageTimestamp']?.toString() ?? data['updatedAt']?.toString() ?? '';
            _seenMessageIds.add('${doc.id}_$lastMsgTime');
          }
        }
        _isInitialMessageLoad = false;
        return;
      }

      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          if (data == null) continue;

          final lastSenderId = data['lastSenderId'] as String? ?? data['senderId'] as String? ?? '';
          final unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
          final isRead = data['isRead'] as bool? ?? true;

          if (lastSenderId != _currentUserId && (unreadCount > 0 || !isRead)) {
            final lastMsgTime = data['lastMessageTimestamp']?.toString() ?? data['updatedAt']?.toString() ?? '';
            final msgKey = '${change.doc.id}_$lastMsgTime';

            if (_seenMessageIds.contains(msgKey)) continue;
            _seenMessageIds.add(msgKey);

            final text = data['lastMessage'] as String? ?? 'New message';
            final defaultSenderName = widget.isTech ? 'Customer' : 'Technician';
            final senderName = widget.isTech
                ? (data['customerName'] as String? ?? defaultSenderName)
                : (data['techName'] as String? ?? defaultSenderName);

            _showAlertBanner('New Message from $senderName', text, Icons.chat_bubble_rounded, const Color(0xFF10B981));
          }
        }
      }
    });
  }

  void _showAlertBanner(String title, String message, IconData icon, Color color) {
    if (!mounted) return;
    try {
      final overlay = Overlay.of(context);
      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, (1.0 - value) * -50),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              message,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);
      Future.delayed(const Duration(seconds: 4), () {
        try {
          overlayEntry.remove();
        } catch (_) {}
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
