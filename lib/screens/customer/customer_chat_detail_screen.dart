import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/models/chat_model.dart';
import 'package:reapiroo/services/chat_service.dart';
import 'package:reapiroo/services/storage_service.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/screens/customer/customer_notification_screen.dart';
import 'package:reapiroo/widgets/booking_card.dart';

class CustomerChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String peerId;
  final String userName;
  final String userRole;
  final String avatarUrl;
  final String? bookingId;

  const CustomerChatDetailScreen({
    super.key,
    this.chatId = '',
    this.peerId = '',
    this.userName = 'Technician',
    this.userRole = 'Plumbing Specialist',
    this.avatarUrl = '',
    this.bookingId,
  });

  @override
  State<CustomerChatDetailScreen> createState() => _CustomerChatDetailScreenState();
}

class _CustomerChatDetailScreenState extends State<CustomerChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  String _currentUserId = '';
  String _currentUserName = 'Customer';
  String _effectiveChatId = '';
  String _effectivePeerId = '';
  String _effectiveAvatar = '';

  @override
  void initState() {
    super.initState();
    _effectivePeerId = widget.peerId.isNotEmpty ? widget.peerId : 'tech_demo';
    _effectiveChatId = widget.chatId.isNotEmpty
        ? widget.chatId
        : ChatService.generateChatId(
            customerId: 'temp_user',
            techId: _effectivePeerId,
            bookingId: widget.bookingId,
          );
    _effectiveAvatar = widget.avatarUrl;
    _initChatAsync();
  }

  Future<void> _initChatAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await ChatService.getEffectiveUserId();
    final customerId = await DatabaseService().resolveUniversalCanonicalId(userId);
    final techId = (_effectivePeerId == 'Reapiroo service') ? 'Reapiroo service' : await DatabaseService().resolveCanonicalTechId(_effectivePeerId);

    final fname = prefs.getString('firstName') ?? prefs.getString('cust_firstName') ?? 'Customer';
    final lname = prefs.getString('lastName') ?? prefs.getString('cust_lastName') ?? '';

    _currentUserId = customerId;
    _currentUserName = '$fname $lname'.trim();
    if (_currentUserName.isEmpty) _currentUserName = 'Customer';

    if (widget.chatId.isEmpty && customerId.isNotEmpty && techId.isNotEmpty) {
      _effectiveChatId = ChatService.generateChatId(
        customerId: customerId,
        techId: techId,
        bookingId: widget.bookingId,
      );
    }

    if (_effectiveAvatar.isEmpty && techId.isNotEmpty) {
      _effectiveAvatar = await DatabaseService().getUniversalUserAvatar(techId);
    }

    try {
      _chatService.getOrCreateChatThread(
        chatId: _effectiveChatId,
        customerId: customerId,
        techId: techId,
        bookingId: widget.bookingId,
        customerName: _currentUserName,
        techName: widget.userName,
        techAvatar: _effectiveAvatar,
      );

      _chatService.markMessagesAsRead(_effectiveChatId, customerId);
    } catch (_) {}

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _effectiveChatId.isEmpty) return;

    _messageController.clear();

    try {
      await _chatService.sendMessage(
        chatId: _effectiveChatId,
        senderId: _currentUserId,
        receiverId: _effectivePeerId,
        text: text,
        senderName: _currentUserName,
        customerId: _currentUserId,
        techId: _effectivePeerId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 22,
                  backgroundImage: _effectiveAvatar.isNotEmpty ? StorageService.getImageProvider(_effectiveAvatar) : null,
                  backgroundColor: Colors.grey.shade300,
                  child: _effectiveAvatar.isEmpty ? const Icon(Icons.person, color: Colors.grey, size: 22) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.userRole,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.black, size: 24),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CustomerNotificationScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const Divider(color: Color(0xFFE5E5EA), height: 1),

          // Real-time Messages Stream (Pre-loaded instantly from local cache)
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _chatService.getMessagesStream(_effectiveChatId, currentUserId: _currentUserId.isNotEmpty ? _currentUserId : 'temp_user', isTech: false),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.black));
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet.\nSend a message to start conversation!',
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
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),

          // Message Input Bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E5EA)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(fontSize: 15, color: Colors.black),
                        decoration: const InputDecoration(
                          hintText: 'Write a message...',
                          hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
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

  Widget _buildMessageBubble(ChatMessageModel message) {
    if (message.isBookingCard) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Align(
          alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.82,
            child: BookingCard(
              techName: message.techName.isNotEmpty ? message.techName : 'Technician',
              id: message.bookingId.isNotEmpty ? (message.bookingId.length > 6 ? message.bookingId.substring(0, 6).toUpperCase() : message.bookingId) : '',
              location: message.location,
              description: message.description,
              serviceImageUrl: message.serviceImageUrl,
              dateText: message.dateText.isNotEmpty ? message.dateText : 'Mon, Dec 23',
              timeText: message.timeText.isNotEmpty ? message.timeText : '12:00',
              status: message.status.isNotEmpty ? message.status : 'Assigned',
              serviceName: message.serviceName.isNotEmpty ? message.serviceName : 'Service',
              badgeText: message.badgeText.isNotEmpty ? message.badgeText : 'Booking',
              onView: () {},
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.black : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isMe ? 18 : 4),
            bottomRight: Radius.circular(message.isMe ? 4 : 18),
          ),
          border: Border.all(
            color: message.isMe ? Colors.black : const Color(0xFFE5E5EA),
          ),
        ),
        child: Column(
          crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isMe ? Colors.white : Colors.black87,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (message.time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                message.time,
                style: TextStyle(
                  color: message.isMe ? Colors.white60 : Colors.black38,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
