import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/models/chat_model.dart';
import 'package:reapiroo/services/chat_service.dart';
import 'package:reapiroo/services/storage_service.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/screens/tech/tech_notification_screen.dart';
import 'package:reapiroo/widgets/booking_card.dart';
import 'package:reapiroo/widgets/notification_bell_button.dart';

class TechChatDetailScreen extends StatefulWidget {
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
  State<TechChatDetailScreen> createState() => _TechChatDetailScreenState();
}

class _TechChatDetailScreenState extends State<TechChatDetailScreen> {
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
    final userId = await ChatService.getEffectiveUserId();
    final techId = await DatabaseService().resolveCanonicalTechId(userId);
    final customerId = (_effectivePeerId == 'Reapiroo service') ? 'Reapiroo service' : await DatabaseService().resolveUniversalCanonicalId(_effectivePeerId);

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
      _effectiveAvatar = await DatabaseService().getUniversalUserAvatar(customerId);
    }

    try {
      _chatService.getOrCreateChatThread(
        chatId: _effectiveChatId,
        customerId: customerId,
        techId: techId,
        bookingId: widget.bookingId,
        customerName: widget.userName,
        customerAvatar: _effectiveAvatar,
        techName: _currentUserName,
      );

      _chatService.markMessagesAsRead(_effectiveChatId, techId, isTech: true);
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
        customerId: _effectivePeerId,
        techId: _currentUserId,
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
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Row(
              children: [
                // Back Button (Black circle with chevron left icon)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundImage: _effectiveAvatar.isNotEmpty ? StorageService.getImageProvider(_effectiveAvatar) : null,
                  backgroundColor: Colors.grey.shade300,
                  child: _effectiveAvatar.isEmpty ? const Icon(Icons.person, color: Colors.grey, size: 22) : null,
                ),
                const SizedBox(width: 12),
                // Name & Subtitle Role
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.userRole,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification Bell Icon
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
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Real-time Messages Stream (Pre-loaded instantly from local cache)
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _chatService.getMessagesStream(_effectiveChatId, currentUserId: _currentUserId.isNotEmpty ? _currentUserId : 'temp_user', isTech: true),
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
                  // White Pill Text Input
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
                  // White Circle Send Button
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
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
    if (msg.isBookingCard) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Align(
          alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.82,
            child: BookingCard(
              techName: msg.techName.isNotEmpty ? msg.techName : 'Technician',
              id: msg.bookingId.isNotEmpty ? (msg.bookingId.length > 6 ? msg.bookingId.substring(0, 6).toUpperCase() : msg.bookingId) : '',
              location: msg.location,
              description: msg.description,
              serviceImageUrl: msg.serviceImageUrl,
              dateText: msg.dateText.isNotEmpty ? msg.dateText : 'Mon, Dec 23',
              timeText: msg.timeText.isNotEmpty ? msg.timeText : '12:00',
              status: msg.status.isNotEmpty ? msg.status : 'Assigned',
              serviceName: msg.serviceName.isNotEmpty ? msg.serviceName : 'Service',
              badgeText: msg.badgeText.isNotEmpty ? msg.badgeText : 'Booking',
              onView: () {},
            ),
          ),
        ),
      );
    }

    if (msg.isMe) {
      // Outgoing Message (Right aligned, Light Grey Bubble)
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.text,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (msg.time.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    msg.time,
                    style: const TextStyle(
                      color: Colors.black38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } else {
      // Incoming Message (Left aligned with small Avatar, Pure Black Bubble)
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _effectiveAvatar.isNotEmpty ? StorageService.getImageProvider(_effectiveAvatar) : null,
              backgroundColor: Colors.grey.shade300,
              child: _effectiveAvatar.isEmpty ? const Icon(Icons.person, color: Colors.grey, size: 18) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (msg.time.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          msg.time,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
