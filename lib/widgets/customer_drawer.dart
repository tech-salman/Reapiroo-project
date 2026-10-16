import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reapiroo/screens/onboarding_screen.dart';
import 'package:reapiroo/screens/customer/customer_main_layout.dart';
import 'package:reapiroo/screens/customer/customer_wallet_screen.dart';
import 'package:reapiroo/screens/customer/customer_notification_screen.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';

class CustomerDrawer extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;

  const CustomerDrawer({
    super.key,
    this.onSelectTab,
  });

  @override
  State<CustomerDrawer> createState() => _CustomerDrawerState();
}

class _CustomerDrawerState extends State<CustomerDrawer> {
  final DatabaseService _dbService = DatabaseService();
  String _userName = 'Customer User';
  String _userEmail = 'customer@example.com';
  String _userAvatar = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final fname = prefs.getString('firstName') ?? prefs.getString('cust_firstName') ?? 'Customer';
    final lname = prefs.getString('lastName') ?? prefs.getString('cust_lastName') ?? 'User';
    final email = prefs.getString('email') ?? firebaseUser?.email ?? 'customer@example.com';
    final profilePhoto = prefs.getString('profile_photo_url') ?? '';
    final googlePhoto = prefs.getString('google_photo_url') ?? '';

    String avatar = '';
    if (profilePhoto.isNotEmpty) {
      avatar = profilePhoto;
    } else if (firebaseUser?.photoURL != null && firebaseUser!.photoURL!.isNotEmpty) {
      avatar = firebaseUser.photoURL!;
    } else if (googlePhoto.isNotEmpty) {
      avatar = googlePhoto;
    }

    final phoneKey = prefs.getString('phoneNumber');
    if (phoneKey != null && phoneKey.isNotEmpty) {
      try {
        final doc = await _dbService.getCustomerProfile(phoneKey);
        if (doc.exists && doc.data() != null) {
          final firestoreAvatar = doc.data()!['avatarUrl'] as String? ?? '';
          if (firestoreAvatar.isNotEmpty) {
            avatar = firestoreAvatar;
            await prefs.setString('profile_photo_url', firestoreAvatar);
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _userName = '$fname $lname'.trim();
      _userEmail = email;
      _userAvatar = avatar;
    });
  }

  void _navigateToTab(int tabIndex) {
    Navigator.pop(context); // Close drawer first

    if (widget.onSelectTab != null) {
      widget.onSelectTab!(tabIndex);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerMainLayout(initialIndex: tabIndex),
        ),
            (route) => false,
      );
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 290.0,
      elevation: 16.0,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // User Header Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        color: Colors.black,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundImage: StorageService.getImageProvider(_userAvatar),
                              backgroundColor: Colors.grey,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _userEmail,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 22),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Navigation Links for Customer
                      _buildDrawerTile(
                        icon: Icons.home_outlined,
                        title: 'Home',
                        onTap: () => _navigateToTab(0),
                      ),
                      _buildDrawerTile(
                        icon: Icons.calendar_month_outlined,
                        title: 'Bookings',
                        onTap: () => _navigateToTab(1),
                      ),
                      _buildDrawerTile(
                        icon: Icons.chat_bubble_outline,
                        title: 'Chat',
                        onTap: () => _navigateToTab(2),
                      ),
                      _buildDrawerTile(
                        icon: Icons.person_outline,
                        title: 'Profile',
                        onTap: () => _navigateToTab(3),
                      ),
                      _buildDrawerTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Wallet',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CustomerWalletScreen()),
                          );
                        },
                      ),
                      _buildDrawerTile(
                        icon: Icons.notifications_none_outlined,
                        title: 'Notifications',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CustomerNotificationScreen()),
                          );
                        },
                      ),

                      const Spacer(),

                      const Divider(color: Color(0xFFE5E5EA), height: 1),

                      // Logout Action Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: ListTile(
                          onTap: _handleLogout,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: const Color(0xFFFFF0F0),
                          leading: const Icon(Icons.logout, color: Color(0xFFD32F2F), size: 22),
                          title: const Text(
                            'Logout',
                            style: TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Icon(icon, color: Colors.black, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black54, size: 20),
    );
  }
}