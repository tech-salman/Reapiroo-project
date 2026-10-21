import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_provider.dart';
import '../../providers/services_providers.dart';
import 'customer_chat_detail_screen.dart';
import 'customer_notification_screen.dart';
import 'customer_main_layout.dart';
import '../../services/storage_service.dart';
import '../../widgets/notification_bell_button.dart';

class CustomerChatScreen extends ConsumerStatefulWidget {
  final bool embedInShell;

  const CustomerChatScreen({
    super.key,
    this.embedInShell = false,
  });

  @override
  ConsumerState<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends ConsumerState<CustomerChatScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () {
              Scaffold.of(ctx).openDrawer();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Chats',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const Spacer(),
        NotificationBellButton(
          isTech: false,
          backgroundColor: Colors.transparent,
          iconColor: Colors.black,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CustomerNotificationScreen()),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedInShell) {
      return const CustomerMainLayout(initialIndex: 2);
    }

    final threadsAsync = ref.watch(userChatThreadsProvider);

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
                      hintText: 'Search chats',
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

        // Chat List Stream
        Expanded(
          child: threadsAsync.when(
            data: (threads) {
              final searchQuery = _searchController.text.trim().toLowerCase();
              final filteredThreads = threads.where((thread) {
                if (searchQuery.isEmpty) return true;
                final peerName = thread.techName.toLowerCase();
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
                  final techId = thread.techId;
                  final peerName = thread.techName.isNotEmpty ? thread.techName : 'Technician';
                  final peerRole = 'Technician';
                  final lastMessage = thread.lastMessage.isNotEmpty ? thread.lastMessage : 'Say hello...';
                  final initialAvatarUrl = thread.techAvatar;
                  final bookingId = thread.bookingId;

                  return FutureBuilder<String>(
                    future: initialAvatarUrl.isNotEmpty ? Future.value(initialAvatarUrl) : ref.read(databaseServiceProvider).getUniversalUserAvatar(techId),
                    builder: (context, avatarSnap) {
                      final avatarUrl = avatarSnap.data ?? initialAvatarUrl;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerChatDetailScreen(
                                chatId: chatId,
                                peerId: techId,
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
                                        fontSize: 16,
                                        fontWeight: thread.unreadCount > 0 ? FontWeight.w900 : FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: thread.unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
                                        fontWeight: thread.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (thread.unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${thread.unreadCount}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
            error: (err, _) => Center(child: Text('Error loading chats: $err', style: const TextStyle(color: Colors.grey))),
          ),
        ),
      ],
    );
  }
}
