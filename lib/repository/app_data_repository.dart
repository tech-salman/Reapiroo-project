import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reapiroo/models/user_profile.dart';
import 'package:reapiroo/models/service_model.dart';
import 'package:reapiroo/models/booking_model.dart';
import 'package:reapiroo/models/request_model.dart';
import 'package:reapiroo/models/offer_model.dart';
import 'package:reapiroo/models/notification_model.dart';
import 'package:reapiroo/models/chat_model.dart';
import 'package:reapiroo/models/wallet_model.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/services/auth_and_user_service.dart';
import 'package:reapiroo/services/booking_service.dart';
import 'package:reapiroo/services/chat_service.dart';
import 'package:reapiroo/services/payment_and_transaction_service.dart';

class AppDataRepository extends ChangeNotifier {
  static final AppDataRepository instance = AppDataRepository._internal();

  factory AppDataRepository() => instance;

  AppDataRepository._internal();

  final DatabaseService _dbService = DatabaseService();
  final AuthAndUserService authAndUserService = AuthAndUserService();
  final BookingService bookingService = BookingService();
  final ChatService chatService = ChatService();
  final PaymentAndTransactionService paymentAndTransactionService = PaymentAndTransactionService();

  UserProfile _userProfile = const UserProfile();
  bool _isLoggedIn = false;
  bool _pushNotificationsEnabled = true;
  bool _darkModeEnabled = false;

  final List<ServiceModel> _services = [];
  List<BookingModel> _bookings = [];
  List<RequestModel> _requests = [];
  List<OfferModel> _offers = [];
  List<NotificationItemModel> _notifications = [];
  List<ChatConversationModel> _conversations = [];
  List<WalletTransactionModel> _walletTransactions = [];

  StreamSubscription? _userSub;
  StreamSubscription? _bookingsSub;
  StreamSubscription? _notifSub;
  StreamSubscription? _chatsSub;

  UserProfile get userProfile => _userProfile;
  bool get isLoggedIn => _isLoggedIn;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get darkModeEnabled => _darkModeEnabled;

  List<ServiceModel> get services => List.unmodifiable(_services);
  List<BookingModel> get bookings => List.unmodifiable(_bookings);
  List<RequestModel> get requests => List.unmodifiable(_requests);
  List<OfferModel> get offers => List.unmodifiable(_offers);
  List<NotificationItemModel> get notifications => List.unmodifiable(_notifications);
  List<ChatConversationModel> get conversations => List.unmodifiable(_conversations);
  List<WalletTransactionModel> get walletTransactions => List.unmodifiable(_walletTransactions);

  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _pushNotificationsEnabled = prefs.getBool('push_notifications') ?? true;
    _darkModeEnabled = prefs.getBool('dark_mode') ?? false;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _isLoggedIn = true;
        _setupRealtimeBackendListeners(user.uid);
      } else {
        _isLoggedIn = false;
        _clearState();
      }
      notifyListeners();
    });
  }

  void _setupRealtimeBackendListeners(String userId) {
    _userSub?.cancel();
    _userSub = _dbService.streamUserProfile(userId).listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final roleStr = data['role'] as String? ?? 'customer';
        final isTech = roleStr == 'technician' || roleStr == 'tech';

        _userProfile = UserProfile(
          firstName: data['fullName'] ?? data['name'] ?? '',
          lastName: '',
          email: data['email'] ?? '',
          phone: data['phoneNumber'] ?? '',
          role: isTech ? UserRole.tech : UserRole.customer,
          bio: data['bio'] ?? '',
          avatarUrl: data['avatarUrl'] ?? data['profilePictureUrl'] ?? '',
          walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
        );
        notifyListeners();
        
        _listenToRoleSpecificData(userId, isTech);
      }
    });
  }
  
  void _listenToRoleSpecificData(String userId, bool isTech) {
    _bookingsSub?.cancel();
    final bookingsCollection = isTech 
        ? _dbService.techRequestsCollection(userId) 
        : _dbService.customerBookingsCollection(userId);
        
    _bookingsSub = bookingsCollection.snapshots().listen((snap) {
      _bookings = snap.docs.map((doc) => BookingModel.fromMap(doc.data(), docId: doc.id)).toList();
      notifyListeners();
    });

    _notifSub?.cancel();
    final notifsCollection = isTech
        ? _dbService.techNotifsCollection(userId)
        : _dbService.customerNotifsCollection(userId);
        
    _notifSub = notifsCollection.snapshots().listen((snap) {
      _notifications = snap.docs.map((doc) {
        final d = doc.data();
        return NotificationItemModel(
          id: doc.id,
          title: d['title'] ?? '',
          description: d['body'] ?? d['description'] ?? '',
          time: 'Just now',
          isRead: d['isRead'] ?? false,
          type: d['type'] ?? 'system',
        );
      }).toList();
      notifyListeners();
    });

    _chatsSub?.cancel();
    final chatsCollection = isTech
        ? _dbService.techChatsCollection(userId)
        : _dbService.customerChatsCollection(userId);
        
    _chatsSub = chatsCollection.snapshots().listen((snap) {
      _conversations = snap.docs.map((doc) {
        final d = doc.data();
        return ChatConversationModel(
          id: doc.id,
          peerName: isTech ? (d['customerName'] ?? 'Customer') : (d['techName'] ?? 'Technician'),
          peerAvatar: isTech ? (d['customerAvatar'] ?? '') : (d['techAvatar'] ?? ''),
          lastMessage: d['lastMessage'] ?? '',
          lastMessageTime: 'Just now',
          unreadCount: 0,
          messages: [],
        );
      }).toList();
      notifyListeners();
    });
  }

  void _clearState() {
    _userSub?.cancel();
    _bookingsSub?.cancel();
    _notifSub?.cancel();
    _chatsSub?.cancel();
    _userProfile = const UserProfile();
    _bookings = [];
    _requests = [];
    _offers = [];
    _notifications = [];
    _conversations = [];
    _walletTransactions = [];
  }

  Future<void> loginUser({required UserRole role, required String email, String? name}) async {
    _isLoggedIn = true;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'user_123';
    await _dbService.saveUserProfile(
      uid: uid,
      role: role == UserRole.tech ? 'tech' : 'customer',
      name: name ?? 'User',
      email: email,
    );
    notifyListeners();
  }

  Future<void> logoutUser() async {
    await FirebaseAuth.instance.signOut();
    _isLoggedIn = false;
    _clearState();
    notifyListeners();
  }

  Future<void> topUpWallet(double amount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _dbService.topUpCustomerBalance(uid, amount, 'card');
    }
  }

  Future<void> markNotificationRead(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final isTech = _userProfile.role == UserRole.tech;
      await _dbService.markNotificationAsRead(uid, id, isTech: isTech);
    }
  }

  Future<void> setPushNotifications(bool val) async {
    _pushNotificationsEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', val);
    notifyListeners();
  }

  Future<void> setDarkMode(bool val) async {
    _darkModeEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', val);
    notifyListeners();
  }
}