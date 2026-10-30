import 'dart:async';
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

  Stream<T> _combineQuerySnapshotStreams<T, S1, S2>(
    Stream<S1> stream1,
    Stream<S2> stream2,
    T Function(S1? data1, S2? data2) combiner,
  ) {
    late StreamController<T> controller;
    S1? latest1;
    S2? latest2;

    StreamSubscription? sub1;
    StreamSubscription? sub2;
    Timer? throttleTimer;
    bool hasPendingEmission = false;

    void emit() {
      if (!controller.isClosed) {
        controller.add(combiner(latest1, latest2));
      }
      hasPendingEmission = false;
    }

    void scheduleEmit() {
      if (throttleTimer?.isActive ?? false) {
        hasPendingEmission = true;
        return;
      }
      emit();
      throttleTimer = Timer(const Duration(milliseconds: 100), () {
        if (hasPendingEmission) {
          emit();
        }
      });
    }

    controller = StreamController<T>(
      onListen: () {
        sub1 = stream1.listen(
          (data) {
            latest1 = data;
            scheduleEmit();
          },
          onError: controller.addError,
        );
        sub2 = stream2.listen(
          (data) {
            latest2 = data;
            scheduleEmit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () {
        throttleTimer?.cancel();
        sub1?.cancel();
        sub2?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<List<ChatMessageModel>> getMessagesStream(
    String chatId, {
    required String currentUserId,
    bool isTech = false,
  }) async* {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phoneNumber') ?? '';
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final altId = (currentUserId == authUid) ? phone : authUid;

    final primaryCollection = isTech
        ? _dbService.techMessagesCollection(currentUserId, chatId)
        : _dbService.customerMessagesCollection(currentUserId, chatId);

    if (altId.isEmpty || altId == currentUserId) {
      yield* primaryCollection.snapshots().map((snapshot) {
        final messages = <ChatMessageModel>[];
        final seenIds = <String>{};

        for (var doc in snapshot.docs) {
          if (seenIds.add(doc.id)) {
            messages.add(ChatMessageModel.fromMap(doc.data(), docId: doc.id, currentUserId: currentUserId));
          }
        }

        messages.sort((a, b) {
          final aTime = a.timestamp ?? DateTime.now();
          final bTime = b.timestamp ?? DateTime.now();
          return aTime.compareTo(bTime);
        });
        return messages;
      });
    } else {
      final altCollection = isTech
          ? _dbService.techMessagesCollection(altId, chatId)
          : _dbService.customerMessagesCollection(altId, chatId);

      yield* _combineQuerySnapshotStreams(
        primaryCollection.snapshots(),
        altCollection.snapshots(),
        (snapshot1, snapshot2) {
          final messages = <ChatMessageModel>[];
          final seenIds = <String>{};

          if (snapshot1 != null) {
            for (var doc in snapshot1.docs) {
              if (seenIds.add(doc.id)) {
                messages.add(ChatMessageModel.fromMap(doc.data(), docId: doc.id, currentUserId: currentUserId));
              }
            }
          }
          if (snapshot2 != null) {
            for (var doc in snapshot2.docs) {
              if (seenIds.add(doc.id)) {
                messages.add(ChatMessageModel.fromMap(doc.data(), docId: doc.id, currentUserId: currentUserId));
              }
            }
          }

          messages.sort((a, b) {
            final aTime = a.timestamp ?? DateTime.now();
            final bTime = b.timestamp ?? DateTime.now();
            return aTime.compareTo(bTime);
          });
          return messages;
        },
      );
    }
  }

  Stream<List<ChatThreadModel>> getUserChatThreads(String userId, {bool isTech = false}) async* {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phoneNumber') ?? '';
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final altId = (userId == authUid) ? phone : authUid;

    final primaryCollection = isTech
        ? _dbService.techChatsCollection(userId)
        : _dbService.customerChatsCollection(userId);

    if (altId.isEmpty || altId == userId) {
      yield* primaryCollection.snapshots().map((snapshot) {
        final threads = <ChatThreadModel>[];
        final seen = <String>{};

        for (var doc in snapshot.docs) {
          if (seen.add(doc.id)) {
            threads.add(ChatThreadModel.fromMap(doc.data(), docId: doc.id));
          }
        }

        threads.sort((a, b) {
          final aTime = a.lastMessageTimestamp ?? DateTime(2000);
          final bTime = b.lastMessageTimestamp ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        return threads;
      });
    } else {
      final altCollection = isTech
          ? _dbService.techChatsCollection(altId)
          : _dbService.customerChatsCollection(altId);

      yield* _combineQuerySnapshotStreams(
        primaryCollection.snapshots(),
        altCollection.snapshots(),
        (snapshot1, snapshot2) {
          final threads = <ChatThreadModel>[];
          final seen = <String>{};

          if (snapshot1 != null) {
            for (var doc in snapshot1.docs) {
              if (seen.add(doc.id)) {
                threads.add(ChatThreadModel.fromMap(doc.data(), docId: doc.id));
              }
            }
          }
          if (snapshot2 != null) {
            for (var doc in snapshot2.docs) {
              if (seen.add(doc.id)) {
                threads.add(ChatThreadModel.fromMap(doc.data(), docId: doc.id));
              }
            }
          }

          threads.sort((a, b) {
            final aTime = a.lastMessageTimestamp ?? DateTime(2000);
            final bTime = b.lastMessageTimestamp ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });
          return threads;
        },
      );
    }
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

      if (unreadQuery.docs.isNotEmpty) {
        final batch = _dbService.db.batch();
        for (var doc in unreadQuery.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }

      // Reset unread count on the thread itself
      final threadCollection = isTech
          ? _dbService.techChatsCollection(currentUserId)
          : _dbService.customerChatsCollection(currentUserId);
          
      await threadCollection.doc(chatId).set({'unreadCount': 0}, SetOptions(merge: true));

    } catch (_) {}
  }
}
