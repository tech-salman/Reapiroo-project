import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reapiroo/providers/notification_provider.dart';

class NotificationBellButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.notifications, color: iconColor, size: 22),
            onPressed: onPressed,
          ),
        ),
        if (unreadCount > 0)
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
                unreadCount > 99 ? '99+' : '$unreadCount',
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
