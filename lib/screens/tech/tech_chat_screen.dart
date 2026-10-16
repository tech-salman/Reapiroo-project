import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/models/chat_model.dart';
import 'package:reapiroo/screens/tech/tech_chat_detail_screen.dart';
import 'package:reapiroo/screens/tech/tech_notification_screen.dart';
import 'package:reapiroo/screens/tech/tech_main_layout.dart';
import 'package:reapiroo/services/chat_service.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/services/storage_service.dart';
import 'package:reapiroo/widgets/notification_bell_button.dart';

class TechChatScreen extends StatefulWidget {
  final bool embedInShell;

  const TechChatScreen({
    super.key,
    this.embedInShell = false,
  });

  @override
  State<TechChatScreen> createState() => _TechChatScreenState();
}

class _TechChatScreenState extends State<TechChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  String _currentUserId = '';
  Set<String> _userCandidates = {};

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> candidates = {};

    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.trim().isNotEmpty) {
      candidates.add(authUid.trim());
    }

    final phone = prefs.getString('phoneNumber') ?? prefs.getString('phone');
    if (phone != null && phone.trim().isNotEmpty) {
      final clean = phone.replaceAll(RegExp(r'\D'), '');
      candidates.add(clean);
      candidates.add('92$clean');
      if (clean.startsWith('92')) candidates.add(clean.substring(2));
    }

    final email = prefs.getString('email') ?? FirebaseAuth.instance.currentUser?.email;
    if (email != null && email.trim().isNotEmpty) {
      candidates.add(email.trim().toLowerCase());
    }

    final uid = candidates.isNotEmpty ? candidates.first : await ChatService.getEffectiveUserId();

    if (mounted) {
      setState(() {
        _currentUserId = uid;
        _userCandidates = candidates;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedInShell) {
      return const TechMainLayout(initialIndex: 2);
    }

    return Column(
      children: [
        // Header Bar (Menu & Notification)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: _buildHeader(),
        ),

        const SizedBox(height: 12),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(26),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(color: Colors.white70, fontSize: 16),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    child: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Top Divider
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(
            color: Color(0xFFE5E5EA),
            height: 1,
            thickness: 1,
          ),
        ),

        // Chat List Stream Builder (100% Backend Real Data)
        Expanded(
          child: _currentUserId.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : StreamBuilder<List<ChatThreadModel>>(
                  stream: ChatService().getUserChatThreads(_currentUserId, isTech: true),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.grey)),
                      );
                    }

                    final threads = snapshot.data ?? [];
                    final searchQuery = _searchController.text.trim().toLowerCase();

                    final filteredThreads = threads.where((thread) {
                      if (searchQuery.isEmpty) return true;
                      final peerName = thread.customerName.toLowerCase();
                      final lastMsg = thread.lastMessage.toLowerCase();
                      return peerName.contains(searchQuery) || lastMsg.contains(searchQuery);
                    }).toList();

                    if (filteredThreads.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No conversations yet',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120),
                      itemCount: filteredThreads.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: Color(0xFFE5E5EA),
                        height: 1,
                        thickness: 1,
                      ),
                      itemBuilder: (context, index) {
                        final thread = filteredThreads[index];
                        final chatId = thread.chatId;
                        final customerId = thread.customerId;
                        final peerName = thread.customerName.isNotEmpty ? thread.customerName : 'Customer';
                        final peerRole = 'Customer';
                        final lastMessage = thread.lastMessage.isNotEmpty ? thread.lastMessage : 'Say hello...';
                        final initialAvatarUrl = thread.customerAvatar;
                        final bookingId = thread.bookingId;

                        return FutureBuilder<String>(
                          future: initialAvatarUrl.isNotEmpty ? Future.value(initialAvatarUrl) : DatabaseService().getUniversalUserAvatar(customerId),
                          builder: (context, avatarSnap) {
                            final avatarUrl = avatarSnap.data ?? initialAvatarUrl;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TechChatDetailScreen(
                                      chatId: chatId,
                                      peerId: customerId,
                                      userName: peerName,
                                      userRole: peerRole,
                                      avatarUrl: avatarUrl,
                                      bookingId: bookingId,
                                    ),
                                  ),
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage: avatarUrl.isNotEmpty ? StorageService.getImageProvider(avatarUrl) : null,
                                      backgroundColor: Colors.grey.shade300,
                                      child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey, size: 28) : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            peerName,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: thread.unreadCount > 0 ? FontWeight.w900 : FontWeight.bold,
                                              color: Colors.black,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            lastMessage,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: thread.unreadCount > 0 ? Colors.black : Colors.black87,
                                              fontWeight: thread.unreadCount > 0 ? FontWeight.w800 : FontWeight.w400,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (thread.unreadCount > 0)
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2F80ED),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${thread.unreadCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: Builder(
            builder: (context) => IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.menu, color: Colors.white, size: 22),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        const Spacer(),
        NotificationBellButton(
          isTech: true,
          backgroundColor: Colors.black,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TechNotificationScreen()),
            );
          },
        ),
      ],
    );
  }
}
