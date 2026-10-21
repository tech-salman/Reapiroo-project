import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String messageId;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String text;
  final bool isRead;
  final DateTime? timestamp;
  final String time;
  final bool isMe;
  final bool isBookingCard;
  final String bookingId;
  final String serviceName;
  final String location;
  final String description;
  final String serviceImageUrl;
  final String dateText;
  final String timeText;
  final String status;
  final String badgeText;
  final String techName;

  ChatMessageModel({
    String? messageId,
    String? id,
    this.chatId = '',
    required this.senderId,
    String? receiverId,
    required this.text,
    this.isRead = false,
    this.timestamp,
    this.time = '',
    this.isMe = false,
    this.isBookingCard = false,
    this.bookingId = '',
    this.serviceName = '',
    this.location = '',
    this.description = '',
    this.serviceImageUrl = '',
    this.dateText = '',
    this.timeText = '',
    this.status = '',
    this.badgeText = '',
    this.techName = '',
  })  : messageId = messageId ?? id ?? '',
        receiverId = receiverId ?? '';

  String get id => messageId;

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'isRead': isRead,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
      'time': time,
      'isBookingCard': isBookingCard,
      'bookingId': bookingId,
      'serviceName': serviceName,
      'location': location,
      'description': description,
      'serviceImageUrl': serviceImageUrl,
      'dateText': dateText,
      'timeText': timeText,
      'status': status,
      'badgeText': badgeText,
      'techName': techName,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, {String? docId, String? currentUserId}) {
    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    final senderId = map['senderId'] as String? ?? map['sender'] as String? ?? '';
    final dt = parseDateTime(map['timestamp'] ?? map['createdAt'] ?? map['lastMessageTimestamp']);

    String formattedTime = map['time'] as String? ?? '';
    if (formattedTime.isEmpty) {
      final timeToFormat = dt ?? DateTime.now();
      final hour = timeToFormat.hour == 0 ? 12 : (timeToFormat.hour > 12 ? timeToFormat.hour - 12 : timeToFormat.hour);
      final ampm = timeToFormat.hour >= 12 ? 'PM' : 'AM';
      final minute = timeToFormat.minute.toString().padLeft(2, '0');
      formattedTime = '$hour:$minute $ampm';
    }

    bool isMe = false;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      final cleanCurrent = currentUserId.trim().toLowerCase();
      final cleanSender = senderId.trim().toLowerCase();
      isMe = cleanSender == cleanCurrent ||
          (cleanCurrent.length > 4 && cleanSender.contains(cleanCurrent)) ||
          (cleanSender.length > 4 && cleanCurrent.contains(cleanSender));
    }

    return ChatMessageModel(
      messageId: map['messageId'] as String? ?? map['id'] as String? ?? docId ?? '',
      chatId: map['chatId'] as String? ?? '',
      senderId: senderId,
      receiverId: map['receiverId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      isRead: map['isRead'] as bool? ?? false,
      timestamp: dt,
      time: formattedTime,
      isMe: isMe,
      isBookingCard: map['isBookingCard'] as bool? ?? false,
      bookingId: map['bookingId'] as String? ?? '',
      serviceName: map['serviceName'] as String? ?? '',
      location: map['location'] as String? ?? '',
      description: map['description'] as String? ?? '',
      serviceImageUrl: map['serviceImageUrl'] as String? ?? '',
      dateText: map['dateText'] as String? ?? '',
      timeText: map['timeText'] as String? ?? '',
      status: map['status'] as String? ?? '',
      badgeText: map['badgeText'] as String? ?? '',
      techName: map['techName'] as String? ?? '',
    );
  }

  ChatMessageModel copyWith({
    String? messageId,
    String? id,
    String? chatId,
    String? senderId,
    String? receiverId,
    String? text,
    bool? isRead,
    DateTime? timestamp,
    String? time,
    bool? isMe,
    bool? isBookingCard,
    String? bookingId,
    String? serviceName,
    String? location,
    String? description,
    String? serviceImageUrl,
    String? dateText,
    String? timeText,
    String? status,
    String? badgeText,
    String? techName,
  }) {
    return ChatMessageModel(
      messageId: messageId ?? id ?? this.messageId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      time: time ?? this.time,
      isMe: isMe ?? this.isMe,
      isBookingCard: isBookingCard ?? this.isBookingCard,
      bookingId: bookingId ?? this.bookingId,
      serviceName: serviceName ?? this.serviceName,
      location: location ?? this.location,
      description: description ?? this.description,
      serviceImageUrl: serviceImageUrl ?? this.serviceImageUrl,
      dateText: dateText ?? this.dateText,
      timeText: timeText ?? this.timeText,
      status: status ?? this.status,
      badgeText: badgeText ?? this.badgeText,
      techName: techName ?? this.techName,
    );
  }
}

class ChatThreadModel {
  final String chatId;
  final String bookingId;
  final List<String> participants;
  final String customerId;
  final String customerName;
  final String customerAvatar;
  final String techId;
  final String techName;
  final String techAvatar;
  final String lastMessage;
  final DateTime? lastMessageTimestamp;
  final String lastSenderId;
  final int unreadCount;

  const ChatThreadModel({
    required this.chatId,
    this.bookingId = '',
    required this.participants,
    this.customerId = '',
    this.customerName = 'Customer',
    this.customerAvatar = '',
    this.techId = '',
    this.techName = 'Technician',
    this.techAvatar = '',
    this.lastMessage = '',
    this.lastMessageTimestamp,
    this.lastSenderId = '',
    this.unreadCount = 0,
  });

  String get peerName => techName.isNotEmpty && techName != 'Technician' ? techName : customerName;
  String get peerAvatar => techAvatar.isNotEmpty ? techAvatar : customerAvatar;

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'bookingId': bookingId,
      'participants': participants,
      'customerId': customerId,
      'customerName': customerName,
      'customerAvatar': customerAvatar,
      'techId': techId,
      'techName': techName,
      'techAvatar': techAvatar,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp != null
          ? Timestamp.fromDate(lastMessageTimestamp!)
          : FieldValue.serverTimestamp(),
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ChatThreadModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    final rawParticipants = map['participants'];
    List<String> parsedParticipants = [];
    if (rawParticipants is List) {
      parsedParticipants = rawParticipants.map((e) => e.toString()).toList();
    }

    return ChatThreadModel(
      chatId: docId ?? map['chatId'] as String? ?? '',
      bookingId: map['bookingId'] as String? ?? map['taskId'] as String? ?? '',
      participants: parsedParticipants,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? map['peerName'] as String? ?? 'Customer',
      customerAvatar: map['customerAvatar'] as String? ?? map['peerAvatar'] as String? ?? '',
      techId: map['techId'] as String? ?? '',
      techName: map['techName'] as String? ?? 'Technician',
      techAvatar: map['techAvatar'] as String? ?? '',
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageTimestamp: parseDateTime(map['lastMessageTimestamp'] ?? map['lastMessageTime'] ?? map['updatedAt']),
      lastSenderId: map['lastSenderId'] as String? ?? '',
      unreadCount: map['unreadCount'] as int? ?? 0,
    );
  }
}

class ChatConversationModel {
  final String id;
  final String peerId;
  final String peerName;
  final String peerRole;
  final String peerAvatar;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final List<ChatMessageModel> messages;

  const ChatConversationModel({
    required this.id,
    this.peerId = '',
    required this.peerName,
    this.peerRole = 'Specialist',
    required this.peerAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    required this.messages,
  });

  ChatConversationModel copyWith({
    String? id,
    String? peerId,
    String? peerName,
    String? peerRole,
    String? peerAvatar,
    String? lastMessage,
    String? lastMessageTime,
    int? unreadCount,
    List<ChatMessageModel>? messages,
  }) {
    return ChatConversationModel(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      peerRole: peerRole ?? this.peerRole,
      peerAvatar: peerAvatar ?? this.peerAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      messages: messages ?? this.messages,
    );
  }
}
