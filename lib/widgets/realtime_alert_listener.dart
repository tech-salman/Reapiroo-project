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
  void dispose() {
    _notifSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  Future<void> _initListeners() async {
    final userId = await ChatService.getEffectiveUserId();
    if (!mounted || userId.isEmpty || userId == 'demo_user') return;
    _currentUserId = userId;

    // 1. Listen to Realtime Notifications
    _notifSub = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collectionGroup('notifications').snapshots().listen((snap) {
      if (!mounted) return;
      if (_isInitialNotificationLoad) {
        for (final doc in snap.docs) {
          _seenNotificationIds.add(doc.id);
        }
        _isInitialNotificationLoad = false;
        return;
      }

      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final docId = change.doc.id;
          if (_seenNotificationIds.contains(docId)) continue;
          _seenNotificationIds.add(docId);

          final data = change.doc.data();
          final path = change.doc.reference.path;
          final isRead = data != null ? (data['isRead'] as bool? ?? false) : false;

          if (!isRead) {
            bool isRelevant = false;
            if (widget.isTech && path.contains('techs')) {
              isRelevant = true;
            } else if (!widget.isTech && path.contains('customers')) {
              isRelevant = true;
            }

            if (isRelevant) {
              final title = data != null ? (data['title'] as String? ?? 'New Notification') : 'New Notification';
              final body = data != null ? (data['body'] as String? ?? data['description'] as String? ?? '') : '';
              _showAlertBanner(title, body, Icons.notifications_active, const Color(0xFF2F80ED));
            }
          }
        }
      }
    });

    // 2. Listen to Realtime Chat Messages
    _chatSub = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collectionGroup('messages').snapshots().listen((snap) {
      if (!mounted) return;
      if (_isInitialMessageLoad) {
        for (final doc in snap.docs) {
          _seenMessageIds.add(doc.id);
        }
        _isInitialMessageLoad = false;
        return;
      }

      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final docId = change.doc.id;
          if (_seenMessageIds.contains(docId)) continue;
          _seenMessageIds.add(docId);

          final data = change.doc.data();
          final senderId = data != null ? (data['senderId'] as String? ?? '') : '';
          final receiverId = data != null ? (data['receiverId'] as String? ?? '') : '';
          final text = data != null ? (data['text'] as String? ?? '') : '';
          final isRead = data != null ? (data['isRead'] as bool? ?? false) : false;
          final path = change.doc.reference.path;

          bool isForMe = receiverId == _currentUserId || path.contains(_currentUserId);
          if (!isRead && senderId != _currentUserId && isForMe) {
            final senderName = data != null ? (data['senderName'] as String? ?? 'New Message') : 'New Message';
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
