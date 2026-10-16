import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database');

  // =========================================================================
  // NATIVE FIRESTORE AUTO ID GENERATOR (Strictly auto-assigned by Firestore)
  // =========================================================================
  String generateFirestoreId() {
    return _db.collection('AUTO').doc().id;
  }

  String generate9DigitId() => generateFirestoreId();

  // =========================================================================
  // EXACT FIRESTORE PATH HELPERS (Strict adherence to firebase database paths.txt)
  // Root collections: 'customers' and 'techs' (No 'USERS' prefix)
  // =========================================================================

  // =========================================================================
  // UNIVERSAL CANONICAL ID RESOLUTION
  // =========================================================================

  Future<String> resolveUniversalCanonicalId(String key) async {
    if (key.isEmpty || key == 'Reapiroo service' || key == 'customer_default') return key;
    try {
      final custDoc = await getCustomerProfile(key);
      if (custDoc.exists) return custDoc.id;
      final techDoc = await getTechProfile(key);
      if (techDoc.exists) return techDoc.id;
    } catch (_) {}
    return key;
  }

  Future<String> resolveCanonicalTechId(String key) async {
    if (key.isEmpty || key == 'Reapiroo service' || key == 'customer_default') return key;

    // 1. Direct check in techs/{key}
    try {
      final doc = await _techAccountDoc(key).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('role') || data.containsKey('name') || data.containsKey('uid') || data.containsKey('phoneNumber')) {
          return doc.id;
        }
      }
    } catch (_) {}

    // 2. Query by phoneNumber
    try {
      final qPhone = await _db.collection('techs').where('phoneNumber', isEqualTo: key).limit(1).get();
      if (qPhone.docs.isNotEmpty) {
        return qPhone.docs.first.id;
      }
    } catch (_) {}

    // 3. Query by uid or userId
    try {
      final qUid = await _db.collection('techs').where('uid', isEqualTo: key).limit(1).get();
      if (qUid.docs.isNotEmpty) {
        return qUid.docs.first.id;
      }
      final qUserId = await _db.collection('techs').where('userId', isEqualTo: key).limit(1).get();
      if (qUserId.docs.isNotEmpty) {
        return qUserId.docs.first.id;
      }
    } catch (_) {}

    // 4. Check TECH_INDEX
    try {
      final indexDoc = await _db.collection('techs').doc('TECH_INDEX').get();
      if (indexDoc.exists && indexDoc.data() != null) {
        final ids = indexDoc.data()?['techIds'] as List<dynamic>? ?? [];
        for (final id in ids) {
          final tId = id.toString();
          if (tId == key) return tId;
          final tDoc = await _techAccountDoc(tId).get();
          if (tDoc.exists && tDoc.data() != null) {
            final tData = tDoc.data()!;
            if (tData['phoneNumber'] == key || tData['uid'] == key || tData['userId'] == key || tData['name'] == key) {
              return tId;
            }
          }
        }
      }
    } catch (_) {}

    // 5. Fallback to getTechProfile
    try {
      final techDoc = await getTechProfile(key);
      if (techDoc.exists) {
        return techDoc.id;
      }
    } catch (_) {}

    return key;
  }

  DocumentReference<Map<String, dynamic>> _customerAccountDoc(String customerId) =>
      _db.collection('customers').doc(customerId);

  DocumentReference<Map<String, dynamic>> _techAccountDoc(String techId) =>
      _db.collection('techs').doc(techId);

  CollectionReference<Map<String, dynamic>> customerBookingsCollection(String customerId) =>
      _db.collection('customers').doc(customerId).collection('bookings');

  CollectionReference<Map<String, dynamic>> customerBidsCollection(String customerId, String bookingId) =>
      _db.collection('customers').doc(customerId).collection('bookings').doc(bookingId).collection('bids');

  CollectionReference<Map<String, dynamic>> customerPaymentsCollection(String customerId, String bookingId, String bidId) =>
      _db.collection('customers').doc(customerId).collection('bookings').doc(bookingId).collection('bids').doc(bidId).collection('payments');

  CollectionReference<Map<String, dynamic>> customerChatsCollection(String customerId) =>
      _db.collection('customers').doc(customerId).collection('chats');

  CollectionReference<Map<String, dynamic>> customerMessagesCollection(String customerId, String chatId) =>
      _db.collection('customers').doc(customerId).collection('chats').doc(chatId).collection('messages');

  CollectionReference<Map<String, dynamic>> customerNotifsCollection(String customerId) =>
      _db.collection('customers').doc(customerId).collection('notifications');

  CollectionReference<Map<String, dynamic>> customerTransactionsCollection(String customerId) =>
      _db.collection('customers').doc(customerId).collection('transactions');

  // TECH PATHS
  CollectionReference<Map<String, dynamic>> techRequestsCollection(String techId) =>
      _db.collection('techs').doc(techId).collection('requests');

  CollectionReference<Map<String, dynamic>> techBidsCollection(String techId, String requestId) =>
      _db.collection('techs').doc(techId).collection('requests').doc(requestId).collection('bids');

  CollectionReference<Map<String, dynamic>> techPaymentsCollection(String techId, String requestId, String bidId) =>
      _db.collection('techs').doc(techId).collection('requests').doc(requestId).collection('bids').doc(bidId).collection('payments');

  CollectionReference<Map<String, dynamic>> techChatsCollection(String techId) =>
      _db.collection('techs').doc(techId).collection('chats');

  CollectionReference<Map<String, dynamic>> techMessagesCollection(String techId, String chatId) =>
      _db.collection('techs').doc(techId).collection('chats').doc(chatId).collection('messages');

  CollectionReference<Map<String, dynamic>> techNotifsCollection(String techId) =>
      _db.collection('techs').doc(techId).collection('notifications');

  CollectionReference<Map<String, dynamic>> techTransactionsCollection(String techId) =>
      _db.collection('techs').doc(techId).collection('transactions');

  // =========================================================================
  // PURGE LEGACY ROOT COLLECTIONS
  // =========================================================================
  Future<void> purgeLegacyCollections() async {
    final legacyCollections = ['bookings', 'chats', 'customer', 'requests', 'tech', 'users', 'transactions', 'tech_locations', 'email_otps', 'CUSTOMERS', 'USERS'];
    for (final col in legacyCollections) {
      try {
        final snap = await _db.collection(col).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
    }
  }

  // =========================================================================
  // 1. ONBOARDING & PROFILING WORKFLOW
  // =========================================================================

  Future<void> saveUserProfile({
    required String uid,
    required String role,
    required String name,
    String? email,
    String? phoneNumber,
    String? gender,
    String? bio,
    double? hourlyRate,
    int? experienceYears,
    bool isVerified = false,
    String? avatarUrl,
    List<String>? selectedServices,
  }) async {
    final authUserUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUid = (authUserUid != null && authUserUid.isNotEmpty) ? authUserUid : uid;
    final userRole = role == 'tech' || role == 'technician' ? 'tech' : 'customer';

    // Clean up any legacy duplicate file created under phoneNumber if authUid is different
    if (authUserUid != null && authUserUid.isNotEmpty && phoneNumber != null && phoneNumber.isNotEmpty && phoneNumber != authUserUid) {
      try {
        if (userRole == 'tech') {
          await _db.collection('techs').doc(phoneNumber).delete();
        } else {
          await _db.collection('customers').doc(phoneNumber).delete();
        }
      } catch (_) {}
    }

    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      'uid': effectiveUid,
      'userId': effectiveUid,
      'role': userRole,
      'name': name,
      'fullName': name,
      'email': email ?? '',
      'phoneNumber': phoneNumber ?? '',
      'gender': gender ?? '',
      'bio': bio ?? '',
      'details': bio ?? '',
      'profilePictureUrl': avatarUrl ?? '',
      'avatarUrl': avatarUrl ?? '',
      'hourlyRate': hourlyRate ?? 0.0,
      'experienceYears': experienceYears ?? 0,
      'isVerified': isVerified,
      'selectedServices': selectedServices ?? ['General Maintenance'],
      'services': selectedServices ?? ['General Maintenance'],
      'service': (selectedServices != null && selectedServices.isNotEmpty) ? selectedServices.first : 'General Maintenance',
      'walletBalance': 0.0,
      'currency': 'AED',
      'updatedAt': now,
      'createdAt': now,
    };

    final cleanEmail = email?.trim().toLowerCase() ?? '';
    final indexEntry = {
      'category': userRole,
      'userId': effectiveUid,
      'email': email ?? '',
      'phone': phoneNumber ?? '',
      'gender': gender ?? '',
    };

    if (userRole == 'tech') {
      await _techAccountDoc(effectiveUid).set(data, SetOptions(merge: true));
      await _db.collection('techs').doc('TECH_INDEX').set({'techIds': FieldValue.arrayUnion([effectiveUid])}, SetOptions(merge: true));
      if (cleanEmail.isNotEmpty) {
        await _db.collection('EMAILS_INDEX').doc('index').set({cleanEmail: indexEntry}, SetOptions(merge: true));
      }
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        await _db.collection('EMAILS_INDEX').doc('index').set({phoneNumber: indexEntry}, SetOptions(merge: true));
      }
      final notifId = generateFirestoreId();
      await techNotifsCollection(effectiveUid).doc(notifId).set({
        'notificationId': notifId,
        'id': notifId,
        'recipientId': effectiveUid,
        'title': 'Welcome to Reapiroo!',
        'body': 'Hi $name, your technician account is set up. Start receiving job requests in your selected field.',
        'description': 'Hi $name, your technician account is set up. Start receiving job requests in your selected field.',
        'type': 'welcome',
        'targetId': '',
        'referenceId': '',
        'isRead': false,
        'createdAt': now,
      });

      final chatId = generateFirestoreId();
      await techChatsCollection(effectiveUid).doc(chatId).set({
        'chatId': chatId,
        'bookingId': '',
        'participants': ['Reapiroo service', effectiveUid],
        'customerId': 'Reapiroo service',
        'customerName': 'Reapiroo service',
        'customerAvatar': 'assets/images/logo.png',
        'techId': effectiveUid,
        'techName': name,
        'techAvatar': avatarUrl ?? '',
        'lastMessage': 'Chat started',
        'updatedAt': now,
        'createdAt': now,
      }, SetOptions(merge: true));

      final msgId = generateFirestoreId();
      await techMessagesCollection(effectiveUid, chatId).doc(msgId).set({
        'messageId': msgId,
        'chatId': chatId,
        'senderId': 'Reapiroo service',
        'receiverId': effectiveUid,
        'text': 'Welcome to Reapiroo Service, $name! Your technician profile is active and ready to bid on jobs.',
        'isRead': false,
        'sentAt': now,
        'timestamp': now,
        'createdAt': now,
      });
    } else {
      await _customerAccountDoc(effectiveUid).set(data, SetOptions(merge: true));
      if (cleanEmail.isNotEmpty) {
        await _db.collection('EMAILS_INDEX').doc('index').set({cleanEmail: indexEntry}, SetOptions(merge: true));
      }
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        await _db.collection('EMAILS_INDEX').doc('index').set({phoneNumber: indexEntry}, SetOptions(merge: true));
      }
      final notifId = generateFirestoreId();
      await customerNotifsCollection(effectiveUid).doc(notifId).set({
        'notificationId': notifId,
        'id': notifId,
        'recipientId': effectiveUid,
        'title': 'Welcome to Reapiroo!',
        'body': 'Hi $name, your account is created. Explore trusted home services.',
        'description': 'Hi $name, your account is created. Explore trusted home services.',
        'type': 'welcome',
        'targetId': '',
        'referenceId': '',
        'isRead': false,
        'createdAt': now,
      });

      final chatId = generateFirestoreId();
      await customerChatsCollection(effectiveUid).doc(chatId).set({
        'chatId': chatId,
        'bookingId': '',
        'participants': [effectiveUid, 'Reapiroo service'],
        'customerId': effectiveUid,
        'customerName': name,
        'customerAvatar': avatarUrl ?? '',
        'techId': 'Reapiroo service',
        'techName': 'Reapiroo service',
        'techAvatar': 'assets/images/logo.png',
        'lastMessage': 'Chat started',
        'updatedAt': now,
        'createdAt': now,
      }, SetOptions(merge: true));

      final msgId = generateFirestoreId();
      await customerMessagesCollection(effectiveUid, chatId).doc(msgId).set({
        'messageId': msgId,
        'chatId': chatId,
        'senderId': 'Reapiroo service',
        'receiverId': effectiveUid,
        'text': 'Welcome to Reapiroo Service, $name! We are here to assist with all your home maintenance needs.',
        'isRead': false,
        'sentAt': now,
        'timestamp': now,
        'createdAt': now,
      });
    }
  }

  Future<void> saveUserByPhone({
    required String phoneNumber,
    required String role,
    required String name,
    required String email,
    String? gender,
    String? details,
    String? service,
    String? avatarUrl,
    bool verified = true,
  }) async {
    final authUserUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUid = (authUserUid != null && authUserUid.isNotEmpty) ? authUserUid : phoneNumber;

    await saveUserProfile(
      uid: effectiveUid,
      role: role,
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      gender: gender,
      avatarUrl: avatarUrl,
      isVerified: verified,
      selectedServices: service != null ? [service] : null,
      bio: details,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(String uid) async {
    var custSnap = await _customerAccountDoc(uid).get();
    if (custSnap.exists) return custSnap;

    var techSnap = await _techAccountDoc(uid).get();
    if (techSnap.exists) return techSnap;

    return custSnap;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile(String uid) {
    return _customerAccountDoc(uid).snapshots().asyncExpand((custSnap) {
      if (custSnap.exists) {
        return _customerAccountDoc(uid).snapshots();
      }
      return _techAccountDoc(uid).snapshots();
    });
  }

  Future<bool> userProfileExists(String uid) async {
    final custSnap = await _customerAccountDoc(uid).get();
    if (custSnap.exists) return true;
    final techSnap = await _techAccountDoc(uid).get();
    return techSnap.exists;
  }

  Future<Map<String, dynamic>?> checkUserExistsByPhone(String phoneNumber) async {
    final custSnap = await _customerAccountDoc(phoneNumber).get();
    if (custSnap.exists) return custSnap.data();
    final techSnap = await _techAccountDoc(phoneNumber).get();
    if (techSnap.exists) return techSnap.data();
    return null;
  }

  Future<Map<String, dynamic>?> checkUserExistsByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;
    try {
      final doc = await _db.collection('EMAILS_INDEX').get();
      for (final d in doc.docs) {
        final data = d.data();
        if (data.containsKey(cleanEmail)) {
          final val = data[cleanEmail];
          String? uid;
          if (val is String) {
            uid = val;
          } else if (val is Map) {
            uid = val['userId'] as String? ?? val['uid'] as String?;
          }
          if (uid != null) {
            final profileDoc = await getUserProfile(uid);
            if (profileDoc.exists) return profileDoc.data();
          }
        }
      }
      final singleDoc = await _db.collection('EMAILS_INDEX').doc('index').get();
      if (singleDoc.exists) {
        final val = singleDoc.data()?[cleanEmail];
        String? uid;
        if (val is String) {
          uid = val;
        } else if (val is Map) {
          uid = val['userId'] as String? ?? val['uid'] as String?;
        }
        if (uid != null) {
          final profileDoc = await getUserProfile(uid);
          if (profileDoc.exists) return profileDoc.data();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> deleteUserData(String uid) async {
    try {
      await _customerAccountDoc(uid).delete();
    } catch (_) {}
    try {
      await _techAccountDoc(uid).delete();
    } catch (_) {}
  }

  // =========================================================================
  // 2. REQUEST, BIDDING, & BOOKING LIFECYCLE (Pure Firestore Auto-IDs)
  // =========================================================================

  Future<String> createBooking({
    required String customerId,
    required String title,
    required String description,
    required String address,
    required double price,
    String? customerName,
    String? serviceCategory,
    double? latitude,
    double? longitude,
    String? serviceImageUrl,
    List<String>? mediaUrls,
    String? sparePartImageUrl,
    String? voiceNoteUrl,
  }) async {
    // Pure Firestore Auto-ID
    final bookingId = generateFirestoreId();
    final now = FieldValue.serverTimestamp();
    final category = serviceCategory ?? 'General Maintenance';

    String customerAvatar = '';
    try {
      final custDoc = await _customerAccountDoc(customerId).get();
      if (custDoc.exists && custDoc.data() != null) {
        final d = custDoc.data()!;
        customerAvatar = d['avatarUrl'] as String? ?? d['profilePictureUrl'] as String? ?? d['photoUrl'] as String? ?? '';
      }
    } catch (_) {}

    final bookingData = {
      'bookingId': bookingId,
      'requestId': bookingId,
      'id': bookingId,
      'customerId': customerId,
      'customerName': customerName ?? 'Customer',
      'customerAvatar': customerAvatar,
      'avatarUrl': customerAvatar,
      'assignedTechId': null,
      'bookedTechId': null,
      'serviceCategory': category,
      'category': category,
      'serviceTitle': title,
      'title': title,
      'description': description,
      'notes': description,
      'status': 'open',
      'location': {
        'address': address,
        'latitude': latitude ?? 0.0,
        'longitude': longitude ?? 0.0,
      },
      'address': address,
      'price': price,
      'agreedPrice': price,
      'budgetRange': {
        'min': price,
        'max': price,
      },
      'acceptedBidId': null,
      'serviceImageUrl': serviceImageUrl ?? '',
      'mediaUrls': mediaUrls ?? [],
      'sparePartImageUrl': sparePartImageUrl ?? '',
      'voiceNoteUrl': voiceNoteUrl ?? '',
      'audioUrl': voiceNoteUrl ?? '',
      'createdAt': now,
      'updatedAt': now,
    };

    // 1. Write Customer booking data directly to customers/{customerId}/bookings/{bookingId}
    await customerBookingsCollection(customerId).doc(bookingId).set(bookingData);

    // 2. Broadcast Customer Notification
    final notifId = generateFirestoreId();
    await customerNotifsCollection(customerId).doc(notifId).set({
      'notificationId': notifId,
      'id': notifId,
      'recipientId': customerId,
      'title': 'Booking Created',
      'body': 'Your request "$title" (#$bookingId) was created successfully.',
      'description': 'Your request "$title" (#$bookingId) was created successfully.',
      'type': 'booking',
      'targetId': bookingId,
      'referenceId': bookingId,
      'isRead': false,
      'createdAt': now,
    });

    // 3. Notify technicians & mirror request at techs/{techId}/requests/{requestId}
    await notifyMatchingTechniciansAndMirrorRequest(
      bookingId: bookingId,
      category: category,
      bookingData: bookingData,
    );

    return bookingId;
  }

  Future<String> createRequest({
    required String customerId,
    required String customerName,
    required String title,
    required String description,
    required String address,
    required double price,
    double? latitude,
    double? longitude,
    String? serviceImageUrl,
    List<String>? mediaUrls,
    String? sparePartImageUrl,
    String? voiceNoteUrl,
  }) async {
    return await createBooking(
      customerId: customerId,
      customerName: customerName,
      title: title,
      description: description,
      address: address,
      price: price,
      latitude: latitude,
      longitude: longitude,
      serviceImageUrl: serviceImageUrl,
      mediaUrls: mediaUrls,
      sparePartImageUrl: sparePartImageUrl,
      voiceNoteUrl: voiceNoteUrl,
    );
  }

  Future<void> notifyMatchingTechniciansAndMirrorRequest({
    required String bookingId,
    required String category,
    required Map<String, dynamic> bookingData,
  }) async {
    final now = FieldValue.serverTimestamp();
    try {
      final techSet = <String>{};
      
      try {
        final techIndexDoc = await _db.collection('techs').doc('TECH_INDEX').get();
        if (techIndexDoc.exists) {
          final data = techIndexDoc.data() ?? {};
          final list = data['techIds'] as List<dynamic>? ?? [];
          techSet.addAll(list.map((e) => e.toString()));
        }
      } catch (_) {}

      try {
        final techsSnap = await _db.collection('techs').get();
        for (var doc in techsSnap.docs) {
          if (doc.id != 'TECH_INDEX') {
            techSet.add(doc.id);
            final data = doc.data();
            final phone = data['phoneNumber'] as String? ?? data['phone'] as String? ?? '';
            final uId = data['uid'] as String? ?? data['userId'] as String? ?? '';
            if (phone.isNotEmpty) techSet.add(phone);
            if (uId.isNotEmpty) techSet.add(uId);
          }
        }
      } catch (_) {}

      for (final techId in techSet) {
        if (techId.isEmpty || techId == 'TECH_INDEX') continue;

        await _db.collection('techs').doc(techId).collection('requests').doc(bookingId).set(bookingData, SetOptions(merge: true));

        final notifId = generateFirestoreId();
        await _db.collection('techs').doc(techId).collection('notifications').doc(notifId).set({
          'notificationId': notifId,
          'id': notifId,
          'recipientId': techId,
          'title': 'New $category Job Available!',
          'body': 'A new job request "${bookingData['title']}" was posted in $category.',
          'description': 'A new job request "${bookingData['title']}" was posted in $category.',
          'type': 'new_job',
          'targetId': bookingId,
          'referenceId': bookingId,
          'isRead': false,
          'createdAt': now,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  // Submit Bid / Offer
  Future<void> submitBid({
    required String bookingId,
    required String techId,
    required String techName,
    required double bidAmount,
    required String proposalNote,
    double techRating = 5.0,
    String estimatedCompletionTime = '1-2 hours',
    String senderRole = 'tech',
    String senderName = '',
    String status = 'pending',
  }) async {
    final canonicalTechId = await resolveCanonicalTechId(techId);
    if (canonicalTechId.isEmpty || canonicalTechId == 'pending') return;

    final bidId = generateFirestoreId();
    final now = FieldValue.serverTimestamp();

    String techAvatar = '';
    try {
      final techDoc = await _techAccountDoc(canonicalTechId).get();
      if (techDoc.exists && techDoc.data() != null) {
        final d = techDoc.data()!;
        techAvatar = d['avatarUrl'] as String? ?? d['profilePictureUrl'] as String? ?? d['photoUrl'] as String? ?? '';
      }
    } catch (_) {}

    final bidData = {
      'bidId': bidId,
      'offerId': bidId,
      'bookingId': bookingId,
      'requestId': bookingId,
      'techId': canonicalTechId,
      'techName': techName,
      'techAvatar': techAvatar,
      'avatarUrl': techAvatar,
      'techRating': techRating,
      'bidAmount': bidAmount,
      'amount': bidAmount,
      'price': bidAmount,
      'proposalNote': proposalNote,
      'notes': proposalNote,
      'estimatedCompletionTime': estimatedCompletionTime,
      'status': status,
      'senderRole': senderRole,
      'senderName': senderName.isNotEmpty
          ? senderName
          : (senderRole == 'customer' ? 'Customer' : techName),
      'createdAt': now,
      'updatedAt': now,
    };

    // 1. Write Tech Bid at techs/{canonicalTechId}/requests/{bookingId}/bids/{bidId}
    await techBidsCollection(canonicalTechId, bookingId).doc(bidId).set(bidData, SetOptions(merge: true));

    // Find Customer ID from request doc
    String customerId = '';
    try {
      final reqDoc = await techRequestsCollection(canonicalTechId).doc(bookingId).get();
      if (reqDoc.exists) {
        customerId = reqDoc.data()?['customerId'] as String? ?? '';
      }
    } catch (_) {}

    if (customerId.isNotEmpty) {
      // 2. Sync to Customer Bid at customers/{customerId}/bookings/{bookingId}/bids/{bidId}
      await customerBidsCollection(customerId, bookingId).doc(bidId).set(bidData, SetOptions(merge: true));

      final isFromCustomer = senderRole == 'customer';
      final notifId = generateFirestoreId();
      final recipientId = isFromCustomer ? canonicalTechId : customerId;
      final collectionRef = isFromCustomer ? techNotifsCollection(recipientId) : customerNotifsCollection(recipientId);

      await collectionRef.doc(notifId).set({
        'notificationId': notifId,
        'id': notifId,
        'recipientId': recipientId,
        'title': isFromCustomer ? 'New Counter-Bid Received!' : 'New Bid Received!',
        'body': isFromCustomer
            ? 'Customer submitted a counter-bid of AED ${bidAmount.toStringAsFixed(0)}.'
            : '$techName submitted a bid of AED ${bidAmount.toStringAsFixed(0)}.',
        'description': isFromCustomer
            ? 'Customer submitted a counter-bid of AED ${bidAmount.toStringAsFixed(0)}.'
            : '$techName submitted a bid of AED ${bidAmount.toStringAsFixed(0)}.',
        'type': 'bid',
        'targetId': bookingId,
        'referenceId': bookingId,
        'isRead': false,
        'createdAt': now,
      }, SetOptions(merge: true));
    }
  }

  Future<void> updateBidStatus({
    required String bookingId,
    required String techId,
    required String customerId,
    required String bidId,
    required String status,
    required String notes,
    required String senderRole,
  }) async {
    final canonicalTechId = await resolveCanonicalTechId(techId);
    final now = FieldValue.serverTimestamp();
    final updateData = {
      'status': status,
      'notes': notes,
      'proposalNote': notes,
      'updatedAt': now,
      'senderRole': senderRole,
    };

    try {
      if (bidId == 'accepted' || bidId == 'declined' || bidId.isEmpty) {
        final snap = await techBidsCollection(canonicalTechId, bookingId).get();
        if (snap.docs.isNotEmpty) {
          for (final doc in snap.docs) {
            await doc.reference.set(updateData, SetOptions(merge: true));
          }
        } else {
          final newBidId = generateFirestoreId();
          await techBidsCollection(canonicalTechId, bookingId).doc(newBidId).set({
            'bidId': newBidId,
            'bookingId': bookingId,
            'amount': 0.0,
            ...updateData,
            'createdAt': now,
          }, SetOptions(merge: true));
        }
      } else {
        await techBidsCollection(canonicalTechId, bookingId).doc(bidId).set(updateData, SetOptions(merge: true));
      }

      if (customerId.isNotEmpty) {
        final custSnap = await customerBidsCollection(customerId, bookingId).get();
        if (custSnap.docs.isNotEmpty) {
          for (final doc in custSnap.docs) {
            await doc.reference.set(updateData, SetOptions(merge: true));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> submitOffer({
    required String requestId,
    required String techId,
    required String techName,
    required double price,
    required String notes,
  }) async {
    final canonicalTechId = await resolveCanonicalTechId(techId);
    await submitBid(
      bookingId: requestId,
      techId: canonicalTechId,
      techName: techName,
      bidAmount: price,
      proposalNote: notes,
    );
  }

  // Accept Bid / Offer with Wallet Balance Payment
  Future<void> acceptBid({
    required String bookingId,
    required String bidId,
    required String techId,
    required String customerId,
    required double amount,
  }) async {
    final cleanCustomerId = await resolveUniversalCanonicalId(customerId);
    final cleanTechId = await resolveCanonicalTechId(techId);

    final custDoc = await getCustomerProfile(cleanCustomerId);
    final currentBal = (custDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

    final paymentId = generateFirestoreId();
    final now = FieldValue.serverTimestamp();
    final updateData = {
      'status': 'booked',
      'bookedTechId': cleanTechId,
      'assignedTechId': cleanTechId,
      'acceptedOfferId': bidId,
      'acceptedBidId': bidId,
      'agreedPrice': amount,
      'updatedAt': now,
    };

    final platformFee = amount * 0.10;
    final netAmount = amount - platformFee;

    final paymentData = {
      'paymentId': paymentId,
      'bookingId': bookingId,
      'bidId': bidId,
      'techId': cleanTechId,
      'customerId': cleanCustomerId,
      'grossAmount': amount,
      'amount': amount,
      'platformFee': platformFee,
      'netAmount': netAmount,
      'paymentMethod': 'wallet_balance',
      'paymentStatus': 'completed',
      'status': 'paid',
      'paidAt': now,
      'timestamp': now,
    };

    // 1. Update Customer Booking & Deduct Real Wallet Balance
    if (cleanCustomerId.isNotEmpty) {
      final custRef = custDoc.exists ? custDoc.reference : _db.collection('customers').doc(cleanCustomerId);
      await custRef.collection('bookings').doc(bookingId).set(updateData, SetOptions(merge: true));

      await custRef.set({
        'walletBalance': currentBal - amount,
        'updatedAt': now,
      }, SetOptions(merge: true));

      // payments collection: customers/{customerId}/bookings/{bookingId}/bids/{bidId}/payments/{paymentId}
      await customerPaymentsCollection(cleanCustomerId, bookingId, bidId).doc(paymentId).set(paymentData);
      await customerTransactionsCollection(cleanCustomerId).doc(paymentId).set(paymentData, SetOptions(merge: true));

      final notifId = generateFirestoreId();
      await customerNotifsCollection(cleanCustomerId).doc(notifId).set({
        'notificationId': notifId,
        'id': notifId,
        'recipientId': cleanCustomerId,
        'title': 'Bid Accepted & Paid',
        'body': 'You accepted bid #$bidId for booking #$bookingId. AED ${amount.toStringAsFixed(0)} deducted from your wallet balance.',
        'description': 'You accepted bid #$bidId for booking #$bookingId. AED ${amount.toStringAsFixed(0)} deducted from your wallet balance.',
        'type': 'booking',
        'targetId': bookingId,
        'referenceId': bookingId,
        'isRead': false,
        'createdAt': now,
      }, SetOptions(merge: true));
    }

    // 2. Update Tech Wallet Balance & Request Details (Real Credit)
    final techDoc = await getTechProfile(cleanTechId);
    final techBal = (techDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
    final techRef = techDoc.exists ? techDoc.reference : _db.collection('techs').doc(cleanTechId);

    await techRef.set({
      'walletBalance': techBal + netAmount,
      'updatedAt': now,
    }, SetOptions(merge: true));

    await techRequestsCollection(cleanTechId).doc(bookingId).set(updateData, SetOptions(merge: true));
    if (cleanCustomerId.isNotEmpty && bidId.isNotEmpty) {
      try {
        await customerBidsCollection(cleanCustomerId, bookingId).doc(bidId).set({'status': 'accepted', 'updatedAt': now}, SetOptions(merge: true));
      } catch (_) {}
    }
    if (cleanTechId.isNotEmpty && bidId.isNotEmpty) {
      try {
        await techBidsCollection(cleanTechId, bookingId).doc(bidId).set({'status': 'accepted', 'updatedAt': now}, SetOptions(merge: true));
      } catch (_) {}
    }
    await updateRequestStatus(bookingId, 'accepted');
    // payments collection: techs/{techId}/requests/{requestId}/bids/{bidId}/payments/{paymentId}
    await techPaymentsCollection(cleanTechId, bookingId, bidId).doc(paymentId).set(paymentData);
    await techTransactionsCollection(cleanTechId).doc(paymentId).set(paymentData, SetOptions(merge: true));

    final techNotifId = generateFirestoreId();
    await techNotifsCollection(cleanTechId).doc(techNotifId).set({
      'notificationId': techNotifId,
      'id': techNotifId,
      'recipientId': cleanTechId,
      'title': 'Offer Accepted & Payment Received!',
      'body': 'Your offer for booking #$bookingId was accepted. AED ${netAmount.toStringAsFixed(0)} credited to your wallet.',
      'description': 'Your offer for booking #$bookingId was accepted. AED ${netAmount.toStringAsFixed(0)} credited to your wallet.',
      'type': 'booking',
      'targetId': bookingId,
      'referenceId': bookingId,
      'isRead': false,
      'createdAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> updateBookingStatus(String customerId, String techId, String bookingId, String newStatus) async {
    final now = FieldValue.serverTimestamp();
    final updateData = {'status': newStatus, 'updatedAt': now};

    if (customerId.isNotEmpty) {
      try { await customerBookingsCollection(customerId).doc(bookingId).update(updateData); } catch (_) {}
    }
    if (techId.isNotEmpty) {
      try { await techRequestsCollection(techId).doc(bookingId).update(updateData); } catch (_) {}
    }
  }

  Future<void> updateRequestStatus(String bookingId, String newStatus) async {
    try {
      String? customerId;

      final techIndexDoc = await _db.collection('techs').doc('TECH_INDEX').get();
      if (techIndexDoc.exists) {
        final tIds = (techIndexDoc.data()?['techIds'] as List<dynamic>? ?? []).map((e) => e.toString());
        for (final tId in tIds) {
          final reqRef = _db.collection('techs').doc(tId).collection('requests').doc(bookingId);
          
          if (customerId == null) {
            final snap = await reqRef.get();
            if (snap.exists) {
               customerId = snap.data()?['customerId'] as String? ?? snap.data()?['userId'] as String?;
            }
          }

          await reqRef.set({'status': newStatus}, SetOptions(merge: true));
        }
      }

      if (customerId != null && customerId.isNotEmpty) {
        await _db.collection('customers').doc(customerId).collection('bookings').doc(bookingId).set({'status': newStatus}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamBidsForBooking(String bookingId, {String? customerId, String? techId}) {
    if (techId != null && techId.isNotEmpty) {
      return _db.collection('techs').doc(techId).collection('requests').doc(bookingId).collection('bids').snapshots();
    }
    if (customerId != null && customerId.isNotEmpty) {
      return _db.collection('customers').doc(customerId).collection('bookings').doc(bookingId).collection('bids').snapshots();
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      return _db.collection('customers').doc(uid).collection('bookings').doc(bookingId).collection('bids').snapshots();
    }
    return Stream.empty();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserNotifications(String userId, {bool isTech = false}) {
    if (isTech) {
      return techNotifsCollection(userId).snapshots();
    }
    return customerNotifsCollection(userId).snapshots();
  }


  // 3. REAL-TIME CONSULTATIVE CHAT WORKFLOW (Pure Firestore Auto-IDs)


  Future<void> getOrCreateChatThread({
    required String chatId,
    required String customerId,
    required String techId,
    required String customerName,
    required String customerAvatar,
    required String techName,
    required String techAvatar,
    String bookingId = '',
  }) async {
    final effectiveChatId = chatId.isNotEmpty ? chatId : generateFirestoreId();
    final now = FieldValue.serverTimestamp();

    final cleanTechId = (techId.isEmpty || techId == 'Reapiroo service')
        ? techId
        : await resolveCanonicalTechId(techId);

    String effectiveCustomerAvatar = customerAvatar;
    if (effectiveCustomerAvatar.isEmpty && customerId.isNotEmpty) {
      try {
        final custDoc = await _customerAccountDoc(customerId).get();
        if (custDoc.exists && custDoc.data() != null) {
          final d = custDoc.data()!;
          effectiveCustomerAvatar = d['avatarUrl'] as String? ?? d['profilePictureUrl'] as String? ?? d['photoUrl'] as String? ?? '';
        }
      } catch (_) {}
    }

    String effectiveTechAvatar = techAvatar;
    if (effectiveTechAvatar.isEmpty && cleanTechId.isNotEmpty && cleanTechId != 'Reapiroo service') {
      try {
        final techDoc = await _techAccountDoc(cleanTechId).get();
        if (techDoc.exists && techDoc.data() != null) {
          final d = techDoc.data()!;
          effectiveTechAvatar = d['avatarUrl'] as String? ?? d['profilePictureUrl'] as String? ?? d['photoUrl'] as String? ?? '';
        }
      } catch (_) {}
    }

    final threadUpdate = {
      'chatId': effectiveChatId,
      'bookingId': bookingId,
      'participants': [customerId, cleanTechId],
      'customerId': customerId,
      'customerName': customerName,
      'customerAvatar': effectiveCustomerAvatar,
      'techId': cleanTechId,
      'techName': techName,
      'techAvatar': effectiveTechAvatar,
      'lastMessage': 'Chat started',
      'updatedAt': now,
      'createdAt': now,
    };

    if (customerId.isNotEmpty) {
      await customerChatsCollection(customerId).doc(effectiveChatId).set(threadUpdate, SetOptions(merge: true));
    }
    if (cleanTechId.isNotEmpty && cleanTechId != 'Reapiroo service') {
      final techDoc = await _techAccountDoc(cleanTechId).get();
      if (techDoc.exists) {
        await techChatsCollection(cleanTechId).doc(effectiveChatId).set(threadUpdate, SetOptions(merge: true));
      }
    }
  }

  Future<void> sendChatMessage({
    required String chatId,
    required String senderId,
    required String text,
    String? mediaUrl,
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
    final now = FieldValue.serverTimestamp();
    final messageId = generateFirestoreId();

    final cId = (customerId != null && customerId.isNotEmpty) ? customerId : senderId;
    final rawTechId = (techId != null && techId.isNotEmpty) ? techId : (senderId != cId ? senderId : '');
    final cleanTechId = (rawTechId.isEmpty || rawTechId == 'Reapiroo service')
        ? rawTechId
        : await resolveCanonicalTechId(rawTechId);

    final tId = cleanTechId;
    final receiverId = senderId == cId ? tId : cId;

    final messageData = {
      'messageId': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text.trim(),
      'mediaUrl': mediaUrl,
      'isRead': false,
      'sentAt': now,
      'timestamp': now,
      'createdAt': now,
      'isBookingCard': isBookingCard,
      'bookingId': bookingId ?? '',
      'serviceName': serviceName ?? '',
      'location': location ?? '',
      'description': description ?? '',
      'serviceImageUrl': serviceImageUrl ?? '',
      'dateText': dateText ?? '',
      'timeText': timeText ?? '',
      'status': status ?? '',
      'badgeText': badgeText ?? '',
      'techName': techName ?? '',
    };

    final threadUpdateSender = {
      'chatId': chatId,
      'lastMessage': isBookingCard ? '[Booking Card]' : text.trim(),
      'lastMessageTime': now,
      'lastMessageTimestamp': now,
      'lastSenderId': senderId,
      'updatedAt': now,
      'unreadCount': 0, // Reset for sender
      if (bookingId != null && bookingId.isNotEmpty) 'bookingId': bookingId,
    };

    final threadUpdateReceiver = {
      'chatId': chatId,
      'lastMessage': isBookingCard ? '[Booking Card]' : text.trim(),
      'lastMessageTime': now,
      'lastMessageTimestamp': now,
      'lastSenderId': senderId,
      'updatedAt': now,
      'unreadCount': FieldValue.increment(1), // Increment for receiver
      if (bookingId != null && bookingId.isNotEmpty) 'bookingId': bookingId,
    };

    if (cId.isNotEmpty && cId != 'Reapiroo service') {
      await customerChatsCollection(cId).doc(chatId).set(
          senderId == cId ? threadUpdateSender : threadUpdateReceiver,
          SetOptions(merge: true));
      // customers/{customerId}/chats/{chatId}/messages/{messageId}
      await customerMessagesCollection(cId, chatId).doc(messageId).set(messageData);
    }

    if (tId.isNotEmpty && tId != 'Reapiroo service' && tId != cId) {
      final techDoc = await _techAccountDoc(tId).get();
      if (techDoc.exists) {
        await techChatsCollection(tId).doc(chatId).set(
            senderId == tId ? threadUpdateSender : threadUpdateReceiver,
            SetOptions(merge: true));
        // techs/{techId}/chats/{chatId}/messages/{messageId}
        await techMessagesCollection(tId, chatId).doc(messageId).set(messageData);
      }
    }
  }


  // 4. FINANCIAL WALLET & NOTIFICATIONS


  Future<void> addNotification({
    required String recipientId,
    required String title,
    required String description,
    required String type,
    String targetId = '',
    bool isTech = false,
  }) async {
    final notifId = generateFirestoreId();
    final now = FieldValue.serverTimestamp();

    final notifData = {
      'notificationId': notifId,
      'id': notifId,
      'recipientId': recipientId,
      'title': title,
      'body': description,
      'description': description,
      'type': type,
      'targetId': targetId,
      'referenceId': targetId,
      'isRead': false,
      'createdAt': now,
    };

    if (isTech) {
      await techNotifsCollection(recipientId).doc(notifId).set(notifData);
    } else {
      await customerNotifsCollection(recipientId).doc(notifId).set(notifData);
    }
  }

  Future<void> markNotificationAsRead(String userId, String notificationId, {bool isTech = false}) async {
    try {
      if (isTech) {
        await techNotifsCollection(userId).doc(notificationId).set({'isRead': true}, SetOptions(merge: true));
      } else {
        await customerNotifsCollection(userId).doc(notificationId).set({'isRead': true}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> topUpCustomerBalance(String customerId, double amount, String paymentMethod) async {
    final topUpId = generateFirestoreId();
    final now = FieldValue.serverTimestamp();

    final custDoc = await _customerAccountDoc(customerId).get();
    final currentBal = (custDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
    await _customerAccountDoc(customerId).set({
      'walletBalance': currentBal + amount,
      'updatedAt': now,
    }, SetOptions(merge: true));

    final txMap = {
      'transactionId': topUpId,
      'paymentId': topUpId,
      'bookingId': 'top_up',
      'customerId': customerId,
      'technicianId': '',
      'amount': amount,
      'platformFee': 0.0,
      'netTechnicianEarnings': 0.0,
      'paymentMethod': 'top_up',
      'paymentStatus': 'completed',
      'timestamp': now,
    };

    await customerTransactionsCollection(customerId).doc(topUpId).set(txMap, SetOptions(merge: true));

    await addNotification(
      recipientId: customerId,
      title: 'Wallet Top-up Successful',
      description: 'AED ${amount.toStringAsFixed(0)} added to your wallet balance.',
      type: 'balance',
      targetId: topUpId,
      isTech: false,
    );
  }

  Future<void> withdrawTechBalance(String techId, double amount, Map<String, dynamic> bankDetails) async {
    final notifId = generateFirestoreId();
    final now = FieldValue.serverTimestamp();

    final techDoc = await getTechProfile(techId);
    final canonicalTechId = techDoc.exists ? techDoc.id : techId;
    final currentBal = (techDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
    if (currentBal >= amount) {
      final docRef = techDoc.exists ? techDoc.reference : _techAccountDoc(canonicalTechId);
      await docRef.set({
        'walletBalance': currentBal - amount,
        'updatedAt': now,
      }, SetOptions(merge: true));

      final paymentId = generate9DigitId();
      final transactionData = {
        'transactionId': paymentId,
        'paymentId': paymentId,
        'bookingId': 'WITHDRAWAL',
        'technicianId': canonicalTechId,
        'amount': -amount,
        'platformFee': 0.0,
        'netTechnicianEarnings': -amount,
        'paymentMethod': 'bank_transfer',
        'paymentStatus': 'requested',
        'bankDetails': bankDetails,
        'timestamp': now,
      };
      await techTransactionsCollection(canonicalTechId).doc(paymentId).set(transactionData, SetOptions(merge: true));
    }

    await addNotification(
      recipientId: canonicalTechId,
      title: 'Withdrawal Requested',
      description: 'Your withdrawal request for AED ${amount.toStringAsFixed(0)} was submitted.',
      type: 'balance',
      targetId: notifId,
      isTech: true,
    );
  }


  // 5. HELPER PROFILE READS & WRITES


  Future<String> getUniversalUserAvatar(String userId) async {
    if (userId.isEmpty) return '';
    if (userId == 'Reapiroo service') return 'assets/images/logo.png';
    try {
      final custDoc = await _customerAccountDoc(userId).get();
      if (custDoc.exists && custDoc.data() != null) {
        final d = custDoc.data()!;
        final url = d['avatarUrl'] as String? ?? d['profilePictureUrl'] as String? ?? d['photoUrl'] as String? ?? '';
        if (url.isNotEmpty) return url;
      }
    } catch (_) {}

    try {
      final techDoc = await _techAccountDoc(userId).get();
      if (techDoc.exists && techDoc.data() != null) {
        final d = techDoc.data()!;
        final url = d['avatarUrl'] as String? ?? d['profilePictureUrl'] as String? ?? d['photoUrl'] as String? ?? '';
        if (url.isNotEmpty) return url;
      }
    } catch (_) {}

    return '';
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getCustomerProfile(String key) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;

    if (key.isNotEmpty) {
      final snap = await _customerAccountDoc(key).get();
      if (snap.exists) return snap;
    }

    if (authUid != null && authUid.isNotEmpty && authUid != key) {
      final snap = await _customerAccountDoc(authUid).get();
      if (snap.exists) return snap;
    }

    if (key.isNotEmpty) {
      try {
        final queryByPhone = await _db.collection('customers').where('phoneNumber', isEqualTo: key).limit(1).get();
        if (queryByPhone.docs.isNotEmpty) return queryByPhone.docs.first;

        final queryByUid = await _db.collection('customers').where('uid', isEqualTo: key).limit(1).get();
        if (queryByUid.docs.isNotEmpty) return queryByUid.docs.first;

        final queryByEmail = await _db.collection('customers').where('email', isEqualTo: key.trim().toLowerCase()).limit(1).get();
        if (queryByEmail.docs.isNotEmpty) return queryByEmail.docs.first;
      } catch (_) {}
    }

    return await _customerAccountDoc(key.isNotEmpty ? key : (authUid ?? 'default')).get();
  }

  Future<void> updateCustomerProfile(String key, Map<String, dynamic> data) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    DocumentSnapshot<Map<String, dynamic>>? docSnap;

    if (authUid != null && authUid.isNotEmpty) {
      docSnap = await getCustomerProfile(authUid);
    }
    if ((docSnap == null || !docSnap.exists) && key.isNotEmpty) {
      docSnap = await getCustomerProfile(key);
    }

    final docRef = docSnap != null && docSnap.exists
        ? docSnap.reference
        : _db.collection('customers').doc(authUid ?? (key.isNotEmpty ? key : generateFirestoreId()));

    final canonicalUid = docRef.id;
    data['uid'] = canonicalUid;
    data['userId'] = canonicalUid;

    await docRef.set(data, SetOptions(merge: true));
    final customerId = docRef.id;
    final newAvatar = data['avatarUrl'] as String? ?? data['profilePictureUrl'] as String? ?? '';
    if (newAvatar.isNotEmpty) {
      try {
        final chatsSnap = await customerChatsCollection(customerId).get();
        for (var doc in chatsSnap.docs) {
          await doc.reference.update({'customerAvatar': newAvatar});
          final techId = doc.data()['techId'] as String? ?? '';
          final chatId = doc.data()['chatId'] as String? ?? doc.id;
          if (techId.isNotEmpty && techId != 'Reapiroo service') {
            try {
              await _db.collection('techs').doc(techId).collection('chats').doc(chatId).update({'customerAvatar': newAvatar});
            } catch (_) {}
          }
        }
        final bookingsSnap = await customerBookingsCollection(customerId).get();
        for (var doc in bookingsSnap.docs) {
          await doc.reference.update({'customerAvatar': newAvatar, 'avatarUrl': newAvatar});
        }
      } catch (_) {}
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getTechProfile(String key) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;

    if (key.isNotEmpty) {
      final snap = await _techAccountDoc(key).get();
      if (snap.exists) return snap;
    }

    if (authUid != null && authUid.isNotEmpty && authUid != key) {
      final snap = await _techAccountDoc(authUid).get();
      if (snap.exists) return snap;
    }

    if (key.isNotEmpty) {
      try {
        final queryByPhone = await _db.collection('techs').where('phoneNumber', isEqualTo: key).limit(1).get();
        if (queryByPhone.docs.isNotEmpty) return queryByPhone.docs.first;

        final queryByUid = await _db.collection('techs').where('uid', isEqualTo: key).limit(1).get();
        if (queryByUid.docs.isNotEmpty) return queryByUid.docs.first;

        final queryByEmail = await _db.collection('techs').where('email', isEqualTo: key.trim().toLowerCase()).limit(1).get();
        if (queryByEmail.docs.isNotEmpty) return queryByEmail.docs.first;
      } catch (_) {}
    }

    return await _techAccountDoc(key.isNotEmpty ? key : (authUid ?? 'default')).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamTechProfile(String key) async* {
    if (key.isEmpty) return;
    final techDoc = await getTechProfile(key);
    final ref = techDoc.exists ? techDoc.reference : _techAccountDoc(key);
    yield* ref.snapshots();
  }

  Future<void> updateTechProfile(String key, Map<String, dynamic> data) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    DocumentSnapshot<Map<String, dynamic>>? docSnap;

    if (authUid != null && authUid.isNotEmpty) {
      docSnap = await getTechProfile(authUid);
    }
    if ((docSnap == null || !docSnap.exists) && key.isNotEmpty) {
      docSnap = await getTechProfile(key);
    }

    final docRef = docSnap != null && docSnap.exists
        ? docSnap.reference
        : _db.collection('techs').doc(authUid ?? (key.isNotEmpty ? key : generateFirestoreId()));

    final canonicalUid = docRef.id;
    data['uid'] = canonicalUid;
    data['userId'] = canonicalUid;

    await docRef.set(data, SetOptions(merge: true));
    final techId = docRef.id;
    final newAvatar = data['avatarUrl'] as String? ?? data['profilePictureUrl'] as String? ?? '';
    if (newAvatar.isNotEmpty) {
      try {
        final chatsSnap = await techChatsCollection(techId).get();
        for (var doc in chatsSnap.docs) {
          await doc.reference.update({'techAvatar': newAvatar});
          final custId = doc.data()['customerId'] as String? ?? '';
          final chatId = doc.data()['chatId'] as String? ?? doc.id;
          if (custId.isNotEmpty && custId != 'Reapiroo service') {
            try {
              await _db.collection('customers').doc(custId).collection('chats').doc(chatId).update({'techAvatar': newAvatar});
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
  }

  Future<void> updateTechAvailability(String key, bool isAvailable) async {
    await _techAccountDoc(key).set({'isAvailable': isAvailable}, SetOptions(merge: true));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getTechBankDetails(String key) async {
    return await _techAccountDoc(key).get();
  }

  Future<void> saveTechBankDetails(String key, Map<String, dynamic> bankData) async {
    await _techAccountDoc(key).set({'bankDetails': bankData}, SetOptions(merge: true));
  }

  CollectionReference<Map<String, dynamic>> techReviewsCollection(String techId) =>
      _db.collection('techs').doc(techId).collection('reviews');

  CollectionReference<Map<String, dynamic>> customerReviewsCollection(String customerId) =>
      _db.collection('customers').doc(customerId).collection('reviews');

  Future<List<Map<String, dynamic>>> fetchTechReviews(String key) async {
    final canonicalId = await resolveCanonicalTechId(key);
    final universalId = await resolveUniversalCanonicalId(key);
    final List<Map<String, dynamic>> allReviews = [];
    final Set<String> seenIds = {};

    final keysToTry = <String>[canonicalId, universalId, key];
    if (key != 'tech_demo') keysToTry.add('tech_demo');

    for (final k in keysToTry) {
      if (k.isEmpty) continue;
      try {
        final snap = await techReviewsCollection(k).get();
        for (var doc in snap.docs) {
          final data = doc.data();
          final rId = data['reviewId'] as String? ?? doc.id;
          if (!seenIds.contains(rId) && data.isNotEmpty) {
            seenIds.add(rId);
            allReviews.add(data);
          }
        }
      } catch (_) {}

      try {
        final doc = await getTechProfile(k);
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final raw = data['reviews'] as List<dynamic>? ?? [];
          for (var r in raw) {
            if (r is Map) {
              final mapR = Map<String, dynamic>.from(r);
              final rId = mapR['reviewId'] as String? ?? mapR['bookingId'] as String? ?? '${mapR['userName']}_${mapR['rating']}';
              if (!seenIds.contains(rId)) {
                seenIds.add(rId);
                allReviews.add(mapR);
              }
            }
          }
        }
      } catch (_) {}
    }

    if (allReviews.isEmpty && key.isNotEmpty) {
      try {
        final q1 = await _db.collection('techs').where('phoneNumber', isEqualTo: key).get();
        for (var doc in q1.docs) {
          final subSnap = await techReviewsCollection(doc.id).get();
          for (var rdoc in subSnap.docs) {
            final data = rdoc.data();
            final rId = data['reviewId'] as String? ?? rdoc.id;
            if (!seenIds.contains(rId)) {
              seenIds.add(rId);
              allReviews.add(data);
            }
          }
          final raw = doc.data()['reviews'] as List<dynamic>? ?? [];
          for (var r in raw) {
            if (r is Map) {
              final mapR = Map<String, dynamic>.from(r);
              final rId = mapR['reviewId'] as String? ?? '${mapR['userName']}_${mapR['rating']}';
              if (!seenIds.contains(rId)) {
                seenIds.add(rId);
                allReviews.add(mapR);
              }
            }
          }
        }
      } catch (_) {}
    }

    return allReviews;
  }

  Future<void> submitTechnicianReview({
    required String techId,
    required String customerId,
    required int rating,
    required String comment,
    required String customerName,
    required String customerAvatar,
    required String bookingId,
  }) async {
    if (techId.isEmpty || techId == 'pending') return;

    final canonicalTechId = await resolveCanonicalTechId(techId);
    if (canonicalTechId.isEmpty || canonicalTechId == 'pending') return;

    final reviewId = generateFirestoreId();
    final now = DateTime.now();
    final dateText = '${_getMonthName(now.month)} ${now.day}, ${now.year}';

    final reviewData = {
      'reviewId': reviewId,
      'bookingId': bookingId,
      'techId': canonicalTechId,
      'customerId': customerId,
      'userName': customerName.isNotEmpty ? customerName : 'Customer',
      'userAvatar': customerAvatar,
      'rating': rating,
      'comment': comment,
      'dateText': dateText,
      'createdAt': Timestamp.fromDate(now),
    };

    // 1. Record under tech path: techs/{canonicalTechId}/reviews/{reviewId}
    await techReviewsCollection(canonicalTechId).doc(reviewId).set(reviewData);

    // 2. Record under customer path: customers/{customerId}/reviews/{reviewId}
    if (customerId.isNotEmpty && customerId != 'customer_default') {
      try {
        await customerReviewsCollection(customerId).doc(reviewId).set(reviewData);
      } catch (_) {}
    }

    // 3. Update Tech Profile document: techs/{canonicalTechId} (reviews array, average rating, count)
    // Only update if the tech profile document actually exists! Do NOT create new tech user IDs.
    final techDocRef = _techAccountDoc(canonicalTechId);
    final techDoc = await techDocRef.get();

    if (techDoc.exists) {
      List<dynamic> existingReviews = [];
      if (techDoc.data() != null) {
        final data = techDoc.data()!;
        existingReviews = List.from(data['reviews'] as List<dynamic>? ?? []);
      }

      existingReviews.insert(0, reviewData);

      int sumRatings = 0;
      for (var r in existingReviews) {
        if (r is Map && r['rating'] != null) {
          sumRatings += (r['rating'] as num).toInt();
        }
      }
      final newTotalReviews = existingReviews.length;
      final newAvgRating = newTotalReviews > 0 ? double.parse((sumRatings / newTotalReviews).toStringAsFixed(1)) : rating.toDouble();

      await techDocRef.set({
        'reviews': existingReviews,
        'rating': newAvgRating,
        'techRating': newAvgRating,
        'totalReviews': newTotalReviews,
        'reviewCount': newTotalReviews,
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }

    // 4. Update booking/request records at customer bookings & tech requests paths
    if (customerId.isNotEmpty && customerId != 'customer_default') {
      try {
        await _db.collection('customers').doc(customerId).collection('bookings').doc(bookingId).set({
          'rating': rating,
          'comment': comment,
          'status': 'completed',
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    try {
      await _db.collection('techs').doc(canonicalTechId).collection('requests').doc(bookingId).set({
        'rating': rating,
        'comment': comment,
        'status': 'completed',
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  String _getMonthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month];
    return 'Jan';
  }
}
