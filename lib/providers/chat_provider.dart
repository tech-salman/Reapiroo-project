import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import 'auth_provider.dart';
import 'services_providers.dart';

/// Stream provider for user's chat threads/conversations
final userChatThreadsProvider = StreamProvider<List<ChatThreadModel>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);

  final roleAsync = ref.watch(userRoleProvider);
  final isTech = roleAsync.asData?.value == 'tech' || roleAsync.asData?.value == 'technician';

  final chatService = ref.watch(chatServiceProvider);
  return chatService.getUserChatThreads(user.uid, isTech: isTech);
});

/// Stream provider for chat messages in a specific chat room ID
final chatMessagesStreamProvider = StreamProvider.family<List<ChatMessageModel>, String>((ref, chatId) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null || chatId.isEmpty) return Stream.value([]);

  final roleAsync = ref.watch(userRoleProvider);
  final isTech = roleAsync.asData?.value == 'tech' || roleAsync.asData?.value == 'technician';

  final chatService = ref.watch(chatServiceProvider);
  return chatService.getMessagesStream(chatId, currentUserId: user.uid, isTech: isTech);
});

/// Controller for performing chat operations
class ChatController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<ChatThreadModel?> getOrCreateChatThread({
    required String customerId,
    required String techId,
    String? chatId,
    String? bookingId,
    String? customerName,
    String? customerAvatar,
    String? techName,
    String? techAvatar,
  }) async {
    state = const AsyncValue.loading();
    ChatThreadModel? thread;
    try {
      final chatService = ref.read(chatServiceProvider);
      thread = await chatService.getOrCreateChatThread(
        customerId: customerId,
        techId: techId,
        chatId: chatId,
        bookingId: bookingId,
        customerName: customerName,
        customerAvatar: customerAvatar,
        techName: techName,
        techAvatar: techAvatar,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    return thread;
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
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        mediaUrl: mediaUrl,
        senderName: senderName,
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
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markMessagesAsRead(String chatId, {bool isTech = false}) async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.markMessagesAsRead(chatId, user.uid, isTech: isTech);
    } catch (_) {}
  }
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, void>(() {
  return ChatController();
});
