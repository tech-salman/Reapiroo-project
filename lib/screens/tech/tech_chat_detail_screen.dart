import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/services_providers.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/notification_bell_button.dart';
import 'tech_notification_screen.dart';

class TechChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String peerId;
  final String userName;
  final String userRole;
  final String avatarUrl;
  final String? bookingId;

  const TechChatDetailScreen({
    super.key,
    this.chatId = '',
    this.peerId = '',
    this.userName = 'Sara Hughs',
    this.userRole = 'Customer',
    this.avatarUrl = '',
    this.bookingId,
  });

  @override
  ConsumerState<TechChatDetailScreen> createState() => _TechChatDetailScreenState();
}

class _TechChatDetailScreenState extends ConsumerState<TechChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  String _currentUserId = '';
  String _currentUserName = 'Technician';
  String _effectiveChatId = '';
  String _effectivePeerId = '';
  String _effectiveAvatar = '';

  @override
  void initState() {
    super.initState();
    _effectivePeerId = widget.peerId.isNotEmpty ? widget.peerId : 'cust_demo';
    _effectiveChatId = widget.chatId.isNotEmpty
        ? widget.chatId
        : ChatService.generateChatId(
            customerId: _effectivePeerId,
            techId: 'temp_user',
            bookingId: widget.bookingId,
          );
    _effectiveAvatar = widget.avatarUrl;
    _initChatAsync();
  }

  Future<void> _initChatAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final dbService = ref.read(databaseServiceProvider);
    final userId = await ChatService.getEffectiveUserId();
    final techId = await dbService.resolveCanonicalTechId(userId);
    final customerId = (_effectivePeerId == 'Reapiroo service') ? 'Reapiroo service' : await dbService.resolveUniversalCanonicalId(_effectivePeerId);

    final fname = prefs.getString('firstName') ?? prefs.getString('tech_firstName') ?? 'Technician';
    final lname = prefs.getString('lastName') ?? prefs.getString('tech_lastName') ?? '';

    _currentUserId = techId;
    _currentUserName = '$fname $lname'.trim();
    if (_currentUserName.isEmpty) _currentUserName = 'Technician';

    if (widget.chatId.isEmpty && customerId.isNotEmpty && techId.isNotEmpty) {
      _effectiveChatId = ChatService.generateChatId(
        customerId: customerId,
        techId: techId,
        bookingId: widget.bookingId,
      );
    }

    if (_effectiveAvatar.isEmpty && customerId.isNotEmpty) {
      _effectiveAvatar = await dbService.getUniversalUserAvatar(customerId);
    }

    try {
      await _chatService.getOrCreateChatThread(
        chatId: _effectiveChatId,
        customerId: customerId,
        techId: techId,
        bookingId: widget.bookingId,
        customerName: widget.userName,
        customerAvatar: _effectiveAvatar,
        techName: _currentUserName,
      );

      await _chatService.markMessagesAsRead(_effectiveChatId, techId, isTech: true);
    } catch (_) {}

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await ref.read(chatControllerProvider.notifier).sendMessage(
        chatId: _effectiveChatId,
        senderId: _currentUserId,
        receiverId: _effectivePeerId,
        text: text,
        senderName: _currentUserName,
        customerId: _effectivePeerId,
        techId: _currentUserId,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesStreamProvider(_effectiveChatId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: _effectiveAvatar.isNotEmpty ? StorageService.getImageProvider(_effectiveAvatar) : null,
              backgroundColor: Colors.grey.shade300,
              child: _effectiveAvatar.isEmpty ? const Icon(Icons.person, color: Colors.grey, size: 20) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const Text(
                    'Active Now',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          NotificationBellButton(
            isTech: true,
            backgroundColor: Colors.transparent,
            iconColor: Colors.black,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TechNotificationScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(color: Color(0xFFE5E5EA), height: 1),
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet.\nType a message below to start chatting!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
              error: (err, _) => Center(child: Text('Error loading messages: $err', style: const TextStyle(color: Colors.grey))),
            ),
          ),

          // Bottom Black Message Input Bar
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(color: Colors.black, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Type message...',
                          hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final bool isMe = msg.senderId == _currentUserId || msg.isMe;

    if (msg.isBookingCard) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: BookingCard(
            techName: msg.techName.isNotEmpty ? msg.techName : 'Technician',
            id: msg.bookingId.isNotEmpty ? msg.bookingId : 'Booking',
            location: msg.location.isNotEmpty ? msg.location : 'Location',
            description: msg.description.isNotEmpty ? msg.description : 'Service Request',
            serviceImageUrl: msg.serviceImageUrl,
            dateText: msg.dateText.isNotEmpty ? msg.dateText : 'Today',
            timeText: msg.timeText.isNotEmpty ? msg.timeText : 'Now',
            status: msg.status.isNotEmpty ? msg.status : 'Booked',
            serviceName: msg.serviceName.isNotEmpty ? msg.serviceName : 'Service Request',
            badgeText: msg.badgeText.isNotEmpty ? msg.badgeText : 'Booked',
            onView: () {},
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.black : const Color(0xFFF1F1F3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
