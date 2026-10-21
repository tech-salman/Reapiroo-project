import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_home_screen.dart';
import 'customer_bookings_screen.dart';
import 'customer_chat_screen.dart';
import 'customer_profile_screen.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/customer_drawer.dart';
import '../../widgets/realtime_alert_listener.dart';

class CustomerMainLayout extends ConsumerStatefulWidget {
  final int initialIndex;

  const CustomerMainLayout({
    super.key,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<CustomerMainLayout> createState() => _CustomerMainLayoutState();
}

class _CustomerMainLayoutState extends ConsumerState<CustomerMainLayout> {
  late int _currentIndex;

  static const List<CustomNavItem> _navItems = [
    CustomNavItem(
      icon: Icons.home,
      label: 'Home',
    ),
    CustomNavItem(
      customIcon: RequestsCalendarIcon(),
      icon: Icons.calendar_today,
      label: 'Bookings',
    ),
    CustomNavItem(
      customIcon: ChatBubblesIcon(),
      icon: Icons.chat_bubble,
      label: 'Chat',
    ),
    CustomNavItem(
      customIcon: ProfileBustIcon(),
      icon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant CustomerMainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const CustomerHomeScreen(embedInShell: true),
      const CustomerBookingsScreen(embedInShell: true),
      const CustomerChatScreen(embedInShell: true),
      const CustomerProfileScreen(embedInShell: true),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      drawer: CustomerDrawer(
        onSelectTab: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      body: RealtimeAlertListener(
        isTech: false,
        child: SafeArea(
          bottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: AnimatedCurvedNavBar(
                  items: _navItems,
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
