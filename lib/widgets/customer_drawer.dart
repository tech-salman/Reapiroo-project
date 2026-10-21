import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../screens/onboarding_screen.dart';
import '../screens/customer/customer_main_layout.dart';
import '../screens/customer/customer_wallet_screen.dart';
import '../screens/customer/customer_notification_screen.dart';
import '../services/storage_service.dart';

class CustomerDrawer extends ConsumerWidget {
  final ValueChanged<int>? onSelectTab;

  const CustomerDrawer({
    super.key,
    this.onSelectTab,
  });

  void _navigateToTab(BuildContext context, int tabIndex) {
    Navigator.pop(context); // Close drawer first

    if (onSelectTab != null) {
      onSelectTab!(tabIndex);
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

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
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
      await ref.read(authControllerProvider.notifier).signOut();

      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider);
    final profile = profileAsync.asData?.value;
    final firebaseUser = ref.watch(currentFirebaseUserProvider);

    final userName = profile?.firstName.isNotEmpty == true
        ? profile!.firstName
        : (firebaseUser?.displayName ?? 'Customer User');
    final userEmail = profile?.email.isNotEmpty == true
        ? profile!.email
        : (firebaseUser?.email ?? 'customer@example.com');
    final userAvatar = profile?.avatarUrl.isNotEmpty == true
        ? profile!.avatarUrl
        : (firebaseUser?.photoURL ?? '');

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
                              backgroundImage: StorageService.getImageProvider(userAvatar),
                              backgroundColor: Colors.grey,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userEmail,
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
                        onTap: () => _navigateToTab(context, 0),
                      ),
                      _buildDrawerTile(
                        icon: Icons.calendar_month_outlined,
                        title: 'Bookings',
                        onTap: () => _navigateToTab(context, 1),
                      ),
                      _buildDrawerTile(
                        icon: Icons.chat_bubble_outline,
                        title: 'Chat',
                        onTap: () => _navigateToTab(context, 2),
                      ),
                      _buildDrawerTile(
                        icon: Icons.person_outline,
                        title: 'Profile',
                        onTap: () => _navigateToTab(context, 3),
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
                          onTap: () => _handleLogout(context, ref),
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
