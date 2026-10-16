import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import 'database_service.dart';

class ChatService {
  final DatabaseService _dbService = DatabaseService();

  ChatService({FirebaseFirestore? db});

  static Future<String> getEffectiveUserId() async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.trim().isNotEmpty) {
      return authUid.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phoneNumber') ?? prefs.getString('phone');
    if (phone != null && phone.trim().isNotEmpty) {
      final clean = phone.replaceAll(RegExp(r'\D'), '');
      return clean.startsWith('92') ? clean : '92$clean';
    }
    final email = prefs.getString('email');
    if (email != null && email.trim().isNotEmpty) {
      return email.trim().toLowerCase();
    }
    return 'demo_user';
  }

  static String generateChatId({
    required String customerId,
    required String techId,
    String? bookingId,
  }) {
    final cleanC = customerId.trim();
    final cleanT = techId.trim();

    final participants = [cleanC, cleanT]..sort();
    final combined = '${participants[0]}:${participants[1]}';

    int hash = 0;
    for (int i = 0; i < combined.length; i++) {
      hash = 31 * hash + combined.codeUnitAt(i);
      hash = hash & 0x7FFFFFFF;
    }

    final nineDigit = 100000000 + (hash % 899999999);
    return nineDigit.toString();
  }

  Future<ChatThreadModel> getOrCreateChatThread({
    required String customerId,
    required String techId,
    String? chatId,
    String? bookingId,
    String? customerName,
    String? customerAvatar,
    String? techName,
    String? techAvatar,
  }) async {
    final cleanCustomerId = await _dbService.resolveUniversalCanonicalId(customerId);
    final cleanTechId = (techId == 'Reapiroo service' || techId.isEmpty) ? techId : await _dbService.resolveCanonicalTechId(techId);

    final effectiveChatId = (chatId != null && chatId.isNotEmpty)
        ? chatId
        : generateChatId(
            customerId: cleanCustomerId,
            techId: cleanTechId,
            bookingId: bookingId,
          );

    await _dbService.getOrCreateChatThread(
      chatId: effectiveChatId,
      customerId: cleanCustomerId,
      techId: cleanTechId,
      customerName: customerName ?? 'Customer',
      customerAvatar: customerAvatar ?? '',
      techName: techName ?? 'Technician',
      techAvatar: techAvatar ?? '',
      bookingId: bookingId ?? '',
    );

    return ChatThreadModel(
      chatId: effectiveChatId,
      bookingId: bookingId ?? '',
      participants: [cleanCustomerId, cleanTechId],
      customerId: cleanCustomerId,
      customerName: customerName ?? 'Customer',
      customerAvatar: customerAvatar ?? '',
      techId: techId,
      techName: techName ?? 'Technician',
      techAvatar: techAvatar ?? '',
      lastMessage: 'Chat started',
      lastSenderId: '',
    );
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
    String? mediaUrl,
    String? senderName,
    String? customerId,
    String? techId,
    bool isBookingCard = false,
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
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && !isBookingCard) return;

    await _dbService.sendChatMessage(
      chatId: chatId,
      senderId: senderId,
      text: trimmed,
      mediaUrl: mediaUrl,
      customerId: customerId,
      techId: techId,
      isBookingCard: isBookingCard,
      bookingId: bookingId,
      serviceName: serviceName,
      location: location,
      description: description,
      serviceImageUrl: serviceImageUrl,
      dateText: dateText,
      timeText: timeText,
      status: status,
      badgeText: badgeText,
      techName: techName,
    );
  }

  Stream<List<ChatMessageModel>> getMessagesStream(
    String chatId, {
    required String currentUserId,
    bool isTech = false,
  }) {
    final collection = isTech
        ? _dbService.techMessagesCollection(currentUserId, chatId)
        : _dbService.customerMessagesCollection(currentUserId, chatId);

    return collection.snapshots().asyncMap((snapshot) async {
      final messages = <ChatMessageModel>[];
      final seenIds = <String>{};

      for (var doc in snapshot.docs) {
        if (seenIds.add(doc.id)) {
          messages.add(ChatMessageModel.fromMap(doc.data(), docId: doc.id, currentUserId: currentUserId));
        }
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phoneNumber') ?? '';
        final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final altId = (currentUserId == authUid) ? phone : authUid;

        if (altId.isNotEmpty && altId != currentUserId) {
          final altCollection = isTech
              ? _dbService.techMessagesCollection(altId, chatId)
              : _dbService.customerMessagesCollection(altId, chatId);
          final altSnap = await altCollection.get();
          for (var doc in altSnap.docs) {
            if (seenIds.add(doc.id)) {
              messages.add(ChatMessageModel.fromMap(doc.data(), docId: doc.id, currentUserId: currentUserId));
            }
          }
        }
      } catch (_) {}

      messages.sort((a, b) {
        final aTime = a.timestamp ?? DateTime.now();
        final bTime = b.timestamp ?? DateTime.now();
        return aTime.compareTo(bTime);
      });
      return messages;
    });
  }

  Stream<List<ChatThreadModel>> getUserChatThreads(String userId, {bool isTech = false}) {
    final collection = isTech
        ? _dbService.techChatsCollection(userId)
        : _dbService.customerChatsCollection(userId);

    return collection.snapshots().asyncMap((snapshot) async {
      final threads = <ChatThreadModel>[];
      final seen = <String>{};

      for (var doc in snapshot.docs) {
        if (seen.add(doc.id)) {
          threads.add(ChatThreadModel.fromMap(doc.data(), docId: doc.id));
        }
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phoneNumber') ?? '';
        final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final altId = (userId == authUid) ? phone : authUid;

        if (altId.isNotEmpty && altId != userId) {
          final altColl = isTech ? _dbService.techChatsCollection(altId) : _dbService.customerChatsCollection(altId);
          final altSnap = await altColl.get();
          for (var doc in altSnap.docs) {
            if (seen.add(doc.id)) {
              threads.add(ChatThreadModel.fromMap(doc.data(), docId: doc.id));
            }
          }
        }
      } catch (_) {}

      threads.sort((a, b) {
        final aTime = a.lastMessageTimestamp ?? DateTime(2000);
        final bTime = b.lastMessageTimestamp ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return threads;
    });
  }

  Future<void> markMessagesAsRead(String chatId, String currentUserId, {bool isTech = false}) async {
    try {
      final collection = isTech
          ? _dbService.techMessagesCollection(currentUserId, chatId)
          : _dbService.customerMessagesCollection(currentUserId, chatId);
          
      final unreadQuery = await collection
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadQuery.docs) {
        await doc.reference.update({'isRead': true});
      }

      // Reset unread count on the thread itself
      final threadCollection = isTech
          ? _dbService.techChatsCollection(currentUserId)
          : _dbService.customerChatsCollection(currentUserId);
          
      await threadCollection.doc(chatId).set({'unreadCount': 0}, SetOptions(merge: true));

    } catch (_) {}
  }
}