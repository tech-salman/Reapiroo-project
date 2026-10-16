import 'package:flutter/material.dart';
import 'package:reapiroo/services/chat_service.dart';

class CustomNavItem {
  final Widget? customIcon;
  final IconData? icon;
  final String label;

  const CustomNavItem({
    this.customIcon,
    this.icon,
    required this.label,
  });
}

class _ChatIconWrapper extends StatefulWidget {
  final Widget child;
  const _ChatIconWrapper({required this.child});

  @override
  State<_ChatIconWrapper> createState() => _ChatIconWrapperState();
}

class _ChatIconWrapperState extends State<_ChatIconWrapper> {
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _checkUnread();
  }

  Future<void> _checkUnread() async {
    final userId = await ChatService.getEffectiveUserId();
    if (userId.isEmpty || userId == 'demo_user') return;

    // Listen to both customer and tech streams just in case
    ChatService().getUserChatThreads(userId, isTech: false).listen((threads) {
      if (!mounted) return;
      bool unread = false;
      for (var t in threads) {
        if (t.unreadCount > 0 && t.lastSenderId != userId) {
          unread = true;
          break;
        }
      }
      if (_hasUnread != unread) {
        setState(() => _hasUnread = unread);
      }
    });

    ChatService().getUserChatThreads(userId, isTech: true).listen((threads) {
      if (!mounted) return;
      bool unread = false;
      for (var t in threads) {
        if (t.unreadCount > 0 && t.lastSenderId != userId) {
          unread = true;
          break;
        }
      }
      // If we already detected unread on the other stream, don't override to false unless both are false.
      if (unread) {
        if (!_hasUnread) setState(() => _hasUnread = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_hasUnread)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class AnimatedCurvedNavBar extends StatelessWidget {
  final List<CustomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AnimatedCurvedNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double barWidth = constraints.maxWidth;
        final int itemCount = items.length;
        final double itemWidth = barWidth / itemCount;
        final double targetNotchX = (currentIndex + 0.5) * itemWidth;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: targetNotchX),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (context, notchX, child) {
            return SizedBox(
              height: 98,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // 1. Bottom Drop Shadow
                  Positioned(
                    bottom: 2,
                    left: 6,
                    right: 6,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.32),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Inner Notch Shadow (Clipped strictly within bar bounds)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: Size(barWidth, 66),
                      painter: _NotchShadowPainter(notchCenterX: notchX),
                    ),
                  ),

                  // 3. Black Curved Bar Base
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: Size(barWidth, 66),
                      painter: _BottomNavPainter(notchCenterX: notchX),
                      child: SizedBox(
                        height: 66,
                        width: barWidth,
                        child: Row(
                          children: List.generate(itemCount, (index) {
                            final isSelected = index == currentIndex;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => onTap(index),
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!isSelected) ...[
                                      items[index].label == 'Chat'
                                          ? _ChatIconWrapper(
                                              child: items[index].customIcon ??
                                                  Icon(
                                                    items[index].icon,
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                            )
                                          : (items[index].customIcon ??
                                              Icon(
                                                items[index].icon,
                                                color: Colors.white,
                                                size: 22,
                                              )),
                                      const SizedBox(height: 4),
                                    ],
                                    Padding(
                                      padding: EdgeInsets.only(
                                        bottom: isSelected ? 11.0 : 8.0,
                                      ),
                                      child: Text(
                                        items[index].label,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSelected ? 12.5 : 9.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),

                  // 4. Floating Circular Selected Icon
                  Positioned(
                    left: notchX - 31,
                    top: 2,
                    child: GestureDetector(
                      onTap: () => onTap(currentIndex),
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          border: Border.all(
                            color: const Color(0xFFE5EEF3),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF90A4AE).withValues(alpha: 0.24),
                              blurRadius: 10,
                              spreadRadius: 2,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: KeyedSubtree(
                              key: ValueKey('selected_tab_$currentIndex'),
                              child: items[currentIndex].label == 'Home'
                                  ? const _HomeSilhouetteIcon()
                                  : items[currentIndex].label == 'Chat'
                                      ? _ChatIconWrapper(
                                          child: items[currentIndex].customIcon ??
                                              Icon(
                                                items[currentIndex].icon,
                                                color: Colors.white,
                                                size: 26,
                                              ),
                                        )
                                      : (items[currentIndex].customIcon ??
                                          Icon(
                                            items[currentIndex].icon,
                                            color: Colors.white,
                                            size: 26,
                                          )),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Rounded Home house silhouette
class _HomeSilhouetteIcon extends StatelessWidget {
  const _HomeSilhouetteIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _HomeSilhouettePainter(),
    );
  }
}

class _HomeSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;

    final path = Path()
      ..moveTo(w * 0.44, h * 0.06)
      ..cubicTo(w * 0.47, h * 0.02, w * 0.53, h * 0.02, w * 0.56, h * 0.06)
      ..lineTo(w * 0.88, h * 0.32)
      ..cubicTo(w * 0.94, h * 0.37, w * 0.96, h * 0.43, w * 0.93, h * 0.50)
      ..lineTo(w * 0.85, h * 0.85)
      ..cubicTo(w * 0.82, h * 0.93, w * 0.75, h * 0.98, w * 0.67, h * 0.98)
      ..lineTo(w * 0.33, h * 0.98)
      ..cubicTo(w * 0.25, h * 0.98, w * 0.18, h * 0.93, w * 0.15, h * 0.85)
      ..lineTo(w * 0.07, h * 0.50)
      ..cubicTo(w * 0.04, h * 0.43, w * 0.06, h * 0.37, w * 0.12, h * 0.32)
      ..close();

    final slot = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.69),
        width: 3.2,
        height: 8.5,
      ),
      const Radius.circular(2.0),
    );

    final finalPath = Path.combine(
      PathOperation.difference,
      path,
      Path()..addRRect(slot),
    );

    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Calendar icon with clock badge
class RequestsCalendarIcon extends StatelessWidget {
  const RequestsCalendarIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      4,
                          (_) => Container(width: 2, height: 2, color: Colors.black),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      4,
                          (_) => Container(width: 2, height: 2, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: const Center(
                  child: Icon(Icons.access_time, size: 7, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Overlapping chat bubbles icon
class ChatBubblesIcon extends StatelessWidget {
  const ChatBubblesIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 22,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 2,
            child: Transform.scale(
              scaleX: -1,
              child: const Icon(
                Icons.chat_bubble,
                color: Colors.white60,
                size: 16,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            top: 0,
            child: Icon(
              Icons.chat_bubble,
              color: Colors.white,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

// Profile bust icon
class ProfileBustIcon extends StatelessWidget {
  const ProfileBustIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.person,
      color: Colors.white,
      size: 22,
    );
  }
}

// Clean Boolean Difference Painter ensuring no artifacts bleed outside the bar
class _BottomNavPainter extends CustomPainter {
  final double notchCenterX;

  _BottomNavPainter({required this.notchCenterX});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    const double barRadius = 26.0;
    const double dipSpread = 42.0;
    const double dipDepth = 32.0;

    // Outer rounded rectangle base
    final baseBar = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(barRadius),
      ));

    // Notch cutout that carves into the top of the bar
    final notchPath = Path()
      ..moveTo(notchCenterX - dipSpread, -10)
      ..lineTo(notchCenterX - dipSpread, 0)
      ..cubicTo(
        notchCenterX - dipSpread * 0.55, 0,
        notchCenterX - dipSpread * 0.45, dipDepth,
        notchCenterX, dipDepth,
      )
      ..cubicTo(
        notchCenterX + dipSpread * 0.45, dipDepth,
        notchCenterX + dipSpread * 0.55, 0,
        notchCenterX + dipSpread, 0,
      )
      ..lineTo(notchCenterX + dipSpread, -10)
      ..close();

    // Subtract cutout from base bar
    final finalPath = Path.combine(PathOperation.difference, baseBar, notchPath);

    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant _BottomNavPainter oldDelegate) {
    return oldDelegate.notchCenterX != notchCenterX;
  }
}

// Inset scoop shadow cleanly clipped to the rounded rectangle
class _NotchShadowPainter extends CustomPainter {
  final double notchCenterX;

  _NotchShadowPainter({required this.notchCenterX});

  @override
  void paint(Canvas canvas, Size size) {
    const double barRadius = 26.0;
    const double dipSpread = 42.0;
    const double dipDepth = 32.0;

    // Hard clip prevents any blurred pixel from bleeding outside the bar's corners
    canvas.clipRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(barRadius),
    ));

    final path = Path()
      ..moveTo(notchCenterX - dipSpread, 0)
      ..cubicTo(
        notchCenterX - dipSpread * 0.55, 0,
        notchCenterX - dipSpread * 0.45, dipDepth,
        notchCenterX, dipDepth,
      )
      ..cubicTo(
        notchCenterX + dipSpread * 0.45, dipDepth,
        notchCenterX + dipSpread * 0.55, 0,
        notchCenterX + dipSpread, 0,
      );

    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant _NotchShadowPainter oldDelegate) {
    return oldDelegate.notchCenterX != notchCenterX;
  }
}