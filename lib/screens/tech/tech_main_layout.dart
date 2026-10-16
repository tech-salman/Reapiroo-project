import 'package:flutter/material.dart';
import 'package:reapiroo/screens/tech/tech_home_screen.dart';
import 'package:reapiroo/screens/tech/tech_requests_screen.dart';
import 'package:reapiroo/screens/tech/tech_chat_screen.dart';
import 'package:reapiroo/screens/tech/tech_profile_screen.dart';
import 'package:reapiroo/widgets/custom_bottom_nav_bar.dart';
import 'package:reapiroo/widgets/tech_drawer.dart';
import 'package:reapiroo/widgets/realtime_alert_listener.dart';

class TechMainLayout extends StatefulWidget {
  final int initialIndex;

  const TechMainLayout({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<TechMainLayout> createState() => _TechMainLayoutState();
}

class _TechMainLayoutState extends State<TechMainLayout> {
  late int _currentIndex;

  static const List<CustomNavItem> _navItems = [
    CustomNavItem(
      icon: Icons.home,
      label: 'Home',
    ),
    CustomNavItem(
      customIcon: RequestsCalendarIcon(),
      icon: Icons.calendar_today,
      label: 'Request',
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
  void didUpdateWidget(covariant TechMainLayout oldWidget) {
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
      const TechHomeScreen(embedInShell: true),
      const TechRequestsScreen(embedInShell: true),
      const TechChatScreen(embedInShell: true),
      const TechProfileScreen(embedInShell: true),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      drawer: TechDrawer(
        onSelectTab: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      body: RealtimeAlertListener(
        isTech: true,
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
