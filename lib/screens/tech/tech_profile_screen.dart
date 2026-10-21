import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reapiroo/providers/services_providers.dart';
import 'package:reapiroo/services/storage_service.dart';
import 'package:reapiroo/screens/onboarding_screen.dart';
import 'tech_main_layout.dart';

enum ProfileSubView {
  main,
  myProfile,
  bioExperience,
  reviews,
  reports,
  termsPolicy,
  helpContactUs,
}

class TechProfileScreen extends ConsumerStatefulWidget {
  final bool embedInShell;

  const TechProfileScreen({
    super.key,
    this.embedInShell = false,
  });

  @override
  ConsumerState<TechProfileScreen> createState() => _TechProfileScreenState();
}

class ReviewData {
  final String name;
  final String avatarUrl;
  final int rating;
  final String date;
  final String comment;

  const ReviewData({
    required this.name,
    required this.avatarUrl,
    required this.rating,
    required this.date,
    required this.comment,
  });
}

class _TechProfileScreenState extends ConsumerState<TechProfileScreen> {
  ProfileSubView _activeView = ProfileSubView.main;

  // My Profile Form Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _workshopLocationController = TextEditingController();
  String? _selectedGender;

  // Bio & Experience state
  String _activeBioTab = 'Services';
  final TextEditingController _bioTextController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController();
  final TextEditingController _experienceYearsController = TextEditingController();
  final Set<String> _selectedServices = {};
  String _profilePhotoUrl = '';

  // Settings & App state
  bool _pushNotificationsEnabled = true;
  bool _darkModeEnabled = false;

  // Real Reports state fetched from Firestore
  int _todayAppointmentsCount = 0;
  int _happyCustomersCount = 0;
  int _jobsCompletedCount = 0;
  double _totalEarnedAmount = 0.0;
  bool _isLoadingReports = false;

  // Reviews state
  String _selectedStarFilter = 'All';

  final List<ReviewData> _allReviews = [];

  final List<Map<String, String>> _allAvailableServices = const [
    {
      'title': 'AC Repair',
      'imageUrl': 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'AC Cleaning',
      'imageUrl': 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Plumber',
      'imageUrl': 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Electrician',
      'imageUrl': 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Carpenter',
      'imageUrl': 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Painter',
      'imageUrl': 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Appliances Repair',
      'imageUrl': 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Handyman',
      'imageUrl': 'https://images.unsplash.com/photo-1505798577917-a65157d3320a?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Local Movers',
      'imageUrl': 'https://images.unsplash.com/photo-1600518464441-9154a4dea21b?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Water Tank Cleaning',
      'imageUrl': 'https://images.unsplash.com/photo-1507652313519-d4e9174996dd?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Cleaning',
      'imageUrl': 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Gardener',
      'imageUrl': 'https://images.unsplash.com/photo-1558904541-efa843a96f01?w=200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Home Services / Maintenance',
      'imageUrl': 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=200&auto=format&fit=crop&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  String get _avatarImage {
    if (_profilePhotoUrl.isNotEmpty) return _profilePhotoUrl;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser?.photoURL != null && firebaseUser!.photoURL!.isNotEmpty) {
      return firebaseUser.photoURL!;
    }
    return '';
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading profile picture...')),
          );
        }

        final prefs = await SharedPreferences.getInstance();
        final firebaseUser = FirebaseAuth.instance.currentUser;
        final uid = firebaseUser?.uid ?? prefs.getString('phoneNumber') ?? '';

        String uploadedUrl = '';
        try {
          uploadedUrl = await StorageService().uploadProfileImageXFile(uid: uid, xfile: pickedFile);
        } catch (_) {}

        if (uploadedUrl.isEmpty) {
          final bytes = await pickedFile.readAsBytes();
          uploadedUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }

        await prefs.setString('profile_photo_url', uploadedUrl);

        final phoneKey = prefs.getString('phoneNumber');
        final dbService = ref.read(databaseServiceProvider);
        if (phoneKey != null && phoneKey.isNotEmpty) {
          await dbService.updateTechProfile(phoneKey, {'avatarUrl': uploadedUrl});
        }

        if (mounted) {
          setState(() {
            _profilePhotoUrl = uploadedUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile picture: $e')),
        );
      }
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final googlePhotoUrl = prefs.getString('google_photo_url') ?? '';
    final profilePhotoUrl = prefs.getString('profile_photo_url') ?? '';

    String photoToUse = '';
    if (profilePhotoUrl.isNotEmpty) {
      photoToUse = profilePhotoUrl;
    } else if (firebaseUser?.photoURL != null && firebaseUser!.photoURL!.isNotEmpty) {
      photoToUse = firebaseUser.photoURL!;
    } else if (googlePhotoUrl.isNotEmpty) {
      photoToUse = googlePhotoUrl;
    }

    _pushNotificationsEnabled = prefs.getBool('push_notifications') ?? true;
    _darkModeEnabled = prefs.getBool('dark_mode') ?? false;

    final phoneKey = prefs.getString('phoneNumber') ?? firebaseUser?.phoneNumber ?? '';
    final uid = firebaseUser?.uid ?? '';
    final dbService = ref.read(databaseServiceProvider);

    // 1. Try Firestore fetch
    DocumentSnapshot<Map<String, dynamic>>? doc;
    if (uid.isNotEmpty) {
      try {
        final snap = await dbService.getTechProfile(uid);
        if (snap.exists && snap.data() != null) doc = snap;
      } catch (_) {}
    }
    if (doc == null && phoneKey.isNotEmpty) {
      try {
        final snap = await dbService.getTechProfile(phoneKey);
        if (snap.exists && snap.data() != null) doc = snap;
      } catch (_) {}
    }

    if (doc != null && doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final avatar = data['avatarUrl'] as String? ?? data['profilePictureUrl'] as String? ?? data['photoUrl'] as String? ?? '';
      if (avatar.isNotEmpty) {
        photoToUse = avatar;
      }
      final name = data['name'] as String? ?? data['fullName'] as String? ?? '';
      final email = data['email'] as String? ?? '';
      final phone = (data['phoneNumber'] as String? ?? data['phone'] as String?) ?? phoneKey;
      final bio = data['bio'] as String? ?? data['details'] as String? ?? '';
      final gender = data['gender'] as String? ?? '';
      final hourly = (data['hourlyRate'] ?? data['rate'])?.toString() ?? '';
      final exp = (data['experienceYears'] ?? data['experience'])?.toString() ?? '';
      final workshop = data['workshopAddress'] as String? ?? data['workshopLocation'] as String? ?? '';

      final rawServices = data['selectedServices'] ?? data['services'] ?? data['service'];
      if (rawServices is List) {
        _selectedServices.addAll(rawServices.map((e) => e.toString()));
      } else if (rawServices is String && rawServices.isNotEmpty) {
        _selectedServices.add(rawServices);
      }

      final parsedReviews = <ReviewData>[];
      try {
        final targetDocId = doc.id;
        final reviewsSnap = await dbService.techReviewsCollection(targetDocId).get();
        for (var rdoc in reviewsSnap.docs) {
          final r = rdoc.data();
          parsedReviews.add(ReviewData(
            name: r['userName'] as String? ?? r['name'] as String? ?? 'Customer',
            avatarUrl: r['userAvatar'] as String? ?? r['avatarUrl'] as String? ?? '',
            rating: (r['rating'] as num?)?.toInt() ?? 5,
            date: r['dateText'] as String? ?? r['date'] as String? ?? 'Recently',
            comment: r['comment'] as String? ?? r['text'] as String? ?? '',
          ));
        }
      } catch (_) {}

      if (parsedReviews.isEmpty) {
        final rawReviews = data['reviews'] as List<dynamic>? ?? [];
        for (var r in rawReviews) {
          if (r is Map) {
            parsedReviews.add(ReviewData(
              name: r['userName'] as String? ?? r['name'] as String? ?? 'Customer',
              avatarUrl: r['userAvatar'] as String? ?? r['avatarUrl'] as String? ?? '',
              rating: (r['rating'] as num?)?.toInt() ?? 5,
              date: r['dateText'] as String? ?? r['date'] as String? ?? 'Recently',
              comment: r['comment'] as String? ?? r['text'] as String? ?? '',
            ));
          }
        }
      }

      var nameParts = name.split(' ');
      var fname = nameParts.isNotEmpty ? nameParts.first : '';
      var lname = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      if (!mounted) return;
      setState(() {
        _firstNameController.text = fname;
        _lastNameController.text = lname;
        _emailController.text = email;
        _phoneController.text = phone;
        _bioTextController.text = bio;
        _hourlyRateController.text = hourly.isNotEmpty ? hourly : '';
        _experienceYearsController.text = exp.isNotEmpty ? exp : '';
        _workshopLocationController.text = workshop.isNotEmpty ? workshop : '';
        _profilePhotoUrl = photoToUse;
        if (['Male', 'Female', 'Other'].contains(gender)) {
          _selectedGender = gender;
        }
        _allReviews.clear();
        _allReviews.addAll(parsedReviews);
      });

      _loadReportsData();
      return;
    }

    // 2. Fallback to SharedPreferences
    if (!mounted) return;

    var fname = prefs.getString('tech_firstName') ?? prefs.getString('firstName') ?? '';
    var lname = prefs.getString('tech_lastName') ?? prefs.getString('lastName') ?? '';

    if (lname.isEmpty && fname.contains(' ')) {
      final parts = fname.split(' ');
      fname = parts.first;
      lname = parts.sublist(1).join(' ');
    }

    final email = prefs.getString('tech_email') ?? prefs.getString('email') ?? firebaseUser?.email ?? '';
    final phone = prefs.getString('phoneNumber') ?? firebaseUser?.phoneNumber ?? '';
    final gender = prefs.getString('tech_gender') ?? prefs.getString('gender') ?? '';
    final bio = prefs.getString('tech_bio') ?? '';
    final service = prefs.getString('tech_service') ?? '';
    final workshop = prefs.getString('tech_workshop_address') ?? '';
    final hourly = prefs.getString('tech_hourly_rate') ?? '';
    final exp = prefs.getString('tech_experience_years') ?? '';

    setState(() {
      _profilePhotoUrl = photoToUse;
      _firstNameController.text = fname;
      _lastNameController.text = lname;
      _emailController.text = email;
      _phoneController.text = phone;
      _bioTextController.text = bio;
      _hourlyRateController.text = hourly;
      _experienceYearsController.text = exp;
      _workshopLocationController.text = workshop;
      if (['Male', 'Female', 'Other'].contains(gender)) {
        _selectedGender = gender;
      }
      if (service.isNotEmpty) {
        _selectedServices.add(service);
      }
    });

    _loadReportsData();
    _loadReviewsData();
  }

  Future<void> _loadReportsData() async {
    if (!mounted) return;
    setState(() => _isLoadingReports = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final phoneKey = prefs.getString('phoneNumber') ?? '';
      final uid = firebaseUser?.uid ?? phoneKey;
      final targetUid = uid.isNotEmpty ? uid : phoneKey;

      if (targetUid.isEmpty) {
        setState(() => _isLoadingReports = false);
        return;
      }

      final requestsSnap = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'database').collection('techs').doc(targetUid).collection('requests').get();

      int jobsDone = 0;
      int todayCount = 0;
      double totalEarned = 0.0;
      final Set<String> uniqueCustomers = {};

      final now = DateTime.now();

      for (var doc in requestsSnap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final custId = data['customerId'] as String? ?? '';
        final price = (data['price'] as num?)?.toDouble() ?? (data['budget'] as num?)?.toDouble() ?? 0.0;

        if (status == 'completed' || status == 'booked' || status == 'paid') {
          jobsDone++;
          totalEarned += price;
          if (custId.isNotEmpty) {
            uniqueCustomers.add(custId);
          }
        }

        final createdAt = data['createdAt'];
        if (createdAt is Timestamp) {
          final dt = createdAt.toDate();
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
            todayCount++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _jobsCompletedCount = jobsDone;
          _todayAppointmentsCount = todayCount > 0 ? todayCount : (jobsDone > 0 ? 1 : 0);
          _happyCustomersCount = uniqueCustomers.isEmpty ? jobsDone : uniqueCustomers.length;
          _totalEarnedAmount = totalEarned;
          _isLoadingReports = false;
        });
      }
      return;
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneKey = _phoneController.text.trim().isNotEmpty
        ? _phoneController.text.trim()
        : (prefs.getString('phoneNumber') ?? '');

    if (phoneKey.isEmpty) return;

    final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
    final email = _emailController.text.trim();
    final bio = _bioTextController.text.trim();
    final hourly = double.tryParse(_hourlyRateController.text.trim()) ?? 50.0;
    final exp = int.tryParse(_experienceYearsController.text.trim()) ?? 5;
    final workshop = _workshopLocationController.text.trim();

    final updateData = <String, dynamic>{
      'name': fullName,
      'email': email,
      'phoneNumber': phoneKey,
      'gender': _selectedGender,
      'details': bio,
      'hourlyRate': hourly,
      'experienceYears': exp,
      'workshopAddress': workshop,
      'services': _selectedServices.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await ref.read(databaseServiceProvider).updateTechProfile(phoneKey, updateData);
    } catch (_) {}

    await prefs.setString('tech_firstName', _firstNameController.text.trim());
    await prefs.setString('tech_lastName', _lastNameController.text.trim());
    await prefs.setString('tech_email', email);
    await prefs.setString('tech_gender', _selectedGender ?? '');
    await prefs.setString('tech_bio', bio);
    await prefs.setString('tech_hourly_rate', _hourlyRateController.text.trim());
    await prefs.setString('tech_experience_years', _experienceYearsController.text.trim());
    await prefs.setString('tech_workshop_address', workshop);
    await prefs.setString('phoneNumber', phoneKey);
  }

  void _openSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFFE5E5EA), height: 1),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      activeTrackColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text('Receive real-time booking alerts & messages', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      value: _pushNotificationsEnabled,
                      onChanged: (val) async {
                        setModalState(() => _pushNotificationsEnabled = val);
                        setState(() => _pushNotificationsEnabled = val);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('push_notifications', val);
                      },
                    ),
                    SwitchListTile(
                      activeTrackColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dark Mode Preference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text('Enable dark theme interface', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      value: _darkModeEnabled,
                      onChanged: (val) async {
                        setModalState(() => _darkModeEnabled = val);
                        setState(() => _darkModeEnabled = val);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('dark_mode', val);
                      },
                    ),
                    const Divider(color: Color(0xFFE5E5EA), height: 1),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_reset, color: Colors.black),
                      title: const Text('Reset / Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text('Send password reset link to your email', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        final email = _emailController.text.trim();
                        if (email.isNotEmpty) {
                          try {
                            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                            messenger.showSnackBar(
                              SnackBar(content: Text('Password reset link sent to $email!')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error sending reset email: $e')),
                            );
                          }
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout, color: Colors.black),
                      title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onTap: () {
                        Navigator.pop(context);
                        _handleLogout();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _workshopLocationController.dispose();
    _bioTextController.dispose();
    _hourlyRateController.dispose();
    _experienceYearsController.dispose();
    super.dispose();
  }

  Future<void> _loadReviewsData() async {
    final prefs = await SharedPreferences.getInstance();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final phoneKey = prefs.getString('phoneNumber') ?? firebaseUser?.phoneNumber ?? '';
    final uid = firebaseUser?.uid ?? '';

    final searchKey = uid.isNotEmpty ? uid : (phoneKey.isNotEmpty ? phoneKey : 'tech_demo');
    final rawList = await ref.read(databaseServiceProvider).fetchTechReviews(searchKey);

    final parsedReviews = <ReviewData>[];
    final Set<String> seenReviewIds = {};

    for (var r in rawList) {
      final rId = r['reviewId'] as String? ?? r['bookingId'] as String? ?? '${r['userName']}_${r['rating']}';
      if (!seenReviewIds.contains(rId)) {
        seenReviewIds.add(rId);
        parsedReviews.add(ReviewData(
          name: r['userName'] as String? ?? r['name'] as String? ?? 'Customer',
          avatarUrl: r['userAvatar'] as String? ?? r['avatarUrl'] as String? ?? '',
          rating: (r['rating'] as num?)?.toInt() ?? 5,
          date: r['dateText'] as String? ?? r['date'] as String? ?? 'Recently',
          comment: r['comment'] as String? ?? r['text'] as String? ?? '',
        ));
      }
    }

    if (!mounted) return;
    setState(() {
      _allReviews.clear();
      _allReviews.addAll(parsedReviews);
    });
  }

  void _navigateToSubView(ProfileSubView subView) {
    setState(() {
      _activeView = subView;
    });
    if (subView == ProfileSubView.reviews) {
      _loadReviewsData();
    }
  }

  void _backToMain() {
    setState(() {
      _activeView = ProfileSubView.main;
    });
  }

  double get _averageRating {
    if (_allReviews.isEmpty) return 0.0;
    final total = _allReviews.fold<int>(0, (acc, item) => acc + item.rating);
    return double.parse((total / _allReviews.length).toStringAsFixed(1));
  }

  List<ReviewData> get _filteredReviews {
    if (_selectedStarFilter == 'All') return _allReviews;
    final targetStars = int.tryParse(_selectedStarFilter.split(' ').first) ?? 5;
    return _allReviews.where((r) => r.rating == targetStars).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedInShell) {
      return const TechMainLayout(initialIndex: 3);
    }

    return PopScope(
      canPop: _activeView == ProfileSubView.main,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _activeView != ProfileSubView.main) {
          _backToMain();
        }
      },
      child: _buildActiveBodyContent(),
    );
  }

  Widget _buildActiveBodyContent() {
    switch (_activeView) {
      case ProfileSubView.main:
        return _buildMainProfileView();
      case ProfileSubView.myProfile:
        return _buildMyProfileView();
      case ProfileSubView.bioExperience:
        return _buildBioExperienceView();
      case ProfileSubView.reviews:
        return _buildReviewsView();
      case ProfileSubView.reports:
        return _buildReportsView();
      case ProfileSubView.termsPolicy:
        return _buildTermsPolicyView();
      case ProfileSubView.helpContactUs:
        return _buildHelpContactView();
    }
  }

  // ==========================================
  // 1. MAIN PROFILE VIEW
  // ==========================================
  Widget _buildMainProfileView() {
    final displayName = '${_firstNameController.text} ${_lastNameController.text}'.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Hamburger Menu Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Builder(
                    builder: (context) => IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                // Working Settings Gear Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.settings, color: Colors.white, size: 22),
                    onPressed: _openSettingsBottomSheet,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // User Avatar & Real Name from Signup
          CircleAvatar(
            radius: 64,
            backgroundImage: StorageService.getImageProvider(_avatarImage),
            backgroundColor: Colors.grey,
          ),
          const SizedBox(height: 14),
          Text(
            displayName.isEmpty ? 'Technician' : displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 24),

          // Menu Options List
          _buildMenuTile(
            icon: Icons.person,
            title: 'My Profile',
            isHighlighted: true,
            onTap: () => _navigateToSubView(ProfileSubView.myProfile),
          ),
          _buildMenuTile(
            icon: Icons.business_center,
            title: 'Bio and Experience',
            onTap: () => _navigateToSubView(ProfileSubView.bioExperience),
          ),
          _buildMenuTile(
            icon: Icons.star,
            title: 'Reviews',
            onTap: () => _navigateToSubView(ProfileSubView.reviews),
          ),
          _buildMenuTile(
            icon: Icons.bar_chart,
            title: 'Reports',
            onTap: () => _navigateToSubView(ProfileSubView.reports),
          ),
          _buildMenuTile(
            icon: Icons.shield_outlined,
            title: 'Terms/Policy',
            onTap: () => _navigateToSubView(ProfileSubView.termsPolicy),
          ),
          _buildMenuTile(
            icon: Icons.help_outline,
            title: 'Help/Contact Us',
            onTap: () => _navigateToSubView(ProfileSubView.helpContactUs),
          ),
          _buildMenuTile(
            icon: Icons.logout,
            title: 'Logout',
            isLogout: true,
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isHighlighted = false,
    bool isLogout = false,
  }) {
    return Container(
      color: isHighlighted ? const Color(0xFFEFEFEF) : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(
          icon,
          color: isLogout ? const Color(0xFFD32F2F) : Colors.black,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isLogout ? const Color(0xFFD32F2F) : Colors.black,
          ),
        ),
        trailing: isLogout
            ? null
            : const Icon(Icons.east, color: Colors.black, size: 22),
      ),
    );
  }

  // ==========================================
  // 2. MY PROFILE SUBVIEW (INCLUDES PHONE & HOURLY RATE)
  // ==========================================
  Widget _buildMyProfileView() {
    return Column(
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: _backToMain,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              children: [
                // Avatar with Camera Badge
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: StorageService.getImageProvider(_avatarImage),
                      backgroundColor: Colors.grey,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // First Name & Last Name Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9FB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E5EA)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.black, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _firstNameController,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                                decoration: const InputDecoration(
                                  hintText: 'First Name',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9FB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E5EA)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.black, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _lastNameController,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                                decoration: const InputDecoration(
                                  hintText: 'Last Name',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Phone Number Input Box (Signup Phone Number)
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.black, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                          decoration: const InputDecoration(
                            hintText: 'Phone Number',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Email Input
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.email, color: Colors.black, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                          decoration: const InputDecoration(
                            hintText: 'Your email',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Hourly Rate Input (Transferred to Personal / Profile)
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_money, color: Colors.black, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _hourlyRateController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                          decoration: const InputDecoration(
                            hintText: 'Hourly Rate (\$/hr)',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Gender Dropdown
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.wc, color: Colors.black, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGender,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedGender = val);
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text('Male')),
                              DropdownMenuItem(value: 'Female', child: Text('Female')),
                              DropdownMenuItem(value: 'Other', child: Text('Other')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveUserData();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile changes saved successfully!')),
                      );
                      _backToMain();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. BIO AND EXPERIENCE SUBVIEW
  // ==========================================
  Widget _buildBioExperienceView() {
    return Column(
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: _backToMain,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Bio and Experience',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4-Tab Segmented Bar
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: ['Personal', 'Services', 'Details', 'Documents'].map((tab) {
                      final isSelected = _activeBioTab == tab;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeBioTab = tab),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tab,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // Active Tab Content
                if (_activeBioTab == 'Personal') ...[
                  const Text(
                    'Bio Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: TextField(
                      controller: _bioTextController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      decoration: const InputDecoration(
                        hintText: 'Describe your skills and experience...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Years of Experience',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.work_history, color: Colors.black, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _experienceYearsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                            decoration: const InputDecoration(
                              hintText: 'Years of Experience',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Hourly Rate (\$/hr)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_money, color: Colors.black, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _hourlyRateController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                            decoration: const InputDecoration(
                              hintText: 'Hourly Rate',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_activeBioTab == 'Services') ...[
                  const Text(
                    'Select Active Services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // All Available Services Cards
                  ..._allAvailableServices.map((service) {
                    final title = service['title']!;
                    final imageUrl = service['imageUrl']!;
                    final isChecked = _selectedServices.contains(title);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            _selectedServices.remove(title);
                          } else {
                            _selectedServices.add(title);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                width: 72,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isChecked ? Colors.black : Colors.grey.shade400,
                                  width: 2,
                                ),
                                color: isChecked ? Colors.black : Colors.transparent,
                              ),
                              child: isChecked
                                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ] else if (_activeBioTab == 'Details') ...[
                  const Text(
                    'Total Completed Jobs',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.task_alt, color: Colors.black, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          '$_jobsCompletedCount Jobs Completed',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Technician Workshop Physical Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront, color: Colors.black, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _workshopLocationController,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
                            decoration: const InputDecoration(
                              hintText: 'Enter Workshop Address',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Documents Tab
                  const Text(
                    'Uploaded Documents',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  _buildDocumentRow('Emirates ID / Passport', 'Verified', Icons.verified_user),
                  _buildDocumentRow('Trade / Plumbing License', 'Verified', Icons.article),
                  _buildDocumentRow('Background Check Certificate', 'Uploaded', Icons.description),
                ],

                const SizedBox(height: 28),

                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveUserData();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bio and Experience updated successfully!')),
                      );
                      _backToMain();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentRow(String title, String status, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'Verified' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: status == 'Verified' ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. REVIEWS SUBVIEW
  // ==========================================
  Widget _buildReviewsView() {
    final displayReviews = _filteredReviews;
    final avgRating = _averageRating;

    return Column(
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: _backToMain,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calculated Overall Rating Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < avgRating.floor() ? Icons.star : Icons.star_half,
                            color: const Color(0xFFFFC107),
                            size: 26,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$avgRating out of 5',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_allReviews.length} reviews',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Star Filter Dropdown Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStarFilter,
                      dropdownColor: Colors.black,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStarFilter = val);
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Stars')),
                        DropdownMenuItem(value: '5 stars', child: Text('5 stars')),
                        DropdownMenuItem(value: '4 stars', child: Text('4 stars')),
                        DropdownMenuItem(value: '3 stars', child: Text('3 stars')),
                        DropdownMenuItem(value: '2 stars', child: Text('2 stars')),
                        DropdownMenuItem(value: '1 star', child: Text('1 star')),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Filtered Review Cards List
                if (displayReviews.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: Text(
                      'No reviews found for $_selectedStarFilter',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayReviews.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: Color(0xFFE5E5EA),
                        height: 28,
                        thickness: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = displayReviews[index];
                        return _buildReviewCardItem(item);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCardItem(ReviewData item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: item.avatarUrl.isNotEmpty && Uri.tryParse(item.avatarUrl)?.hasAbsolutePath == true
                  ? NetworkImage(item.avatarUrl)
                  : null,
              backgroundColor: Colors.grey.shade300,
              child: (item.avatarUrl.isEmpty || Uri.tryParse(item.avatarUrl)?.hasAbsolutePath != true)
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  Icons.star,
                  color: i < item.rating ? const Color(0xFFFFC107) : Colors.grey.shade300,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.date,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.comment,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Colors.black87,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 5. REPORTS SUBVIEW (REAL FIRESTORE DATA)
  // ==========================================
  Widget _buildReportsView() {
    return Column(
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: _backToMain,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Reports',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black),
                onPressed: _loadReportsData,
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoadingReports
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.92,
                    children: [
                      _buildReportCard(
                        iconBgColor: const Color(0xFF8B5CF6),
                        icon: Icons.calendar_month,
                        title: 'Today Appointments',
                        value: '$_todayAppointmentsCount',
                      ),
                      _buildReportCard(
                        iconBgColor: const Color(0xFFF97316),
                        icon: Icons.people_alt,
                        title: 'Happy Customers',
                        value: '$_happyCustomersCount',
                      ),
                      _buildReportCard(
                        iconBgColor: const Color(0xFF10B981),
                        icon: Icons.inventory_2_outlined,
                        title: 'Jobs Completed',
                        value: '$_jobsCompletedCount',
                      ),
                      _buildReportCard(
                        iconBgColor: const Color(0xFF06B6D4),
                        icon: Icons.trending_up,
                        title: 'Total Earned',
                        value: 'AED ${_totalEarnedAmount.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required Color iconBgColor,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. TERMS & POLICY SUBVIEW
  // ==========================================
  Widget _buildTermsPolicyView() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: _backToMain,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Terms & Policies',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPolicyCard(
                  icon: Icons.gavel,
                  title: '1. Terms of Service',
                  content:
                      'By registering as a technician on Reapiroo, you agree to fulfill accepted service bookings professionally and punctually. Misrepresentation of skills or unexcused cancellations may lead to account suspension.',
                ),
                const SizedBox(height: 14),
                _buildPolicyCard(
                  icon: Icons.security,
                  title: '2. Privacy & Data Protection',
                  content:
                      'We prioritize your privacy. Customer contact details and job locations are encrypted and shared strictly for fulfilling scheduled service tasks. Personal data is never sold to third parties.',
                ),
                const SizedBox(height: 14),
                _buildPolicyCard(
                  icon: Icons.monetization_on_outlined,
                  title: '3. Payout & Commission Policy',
                  content:
                      'Platform commissions are deducted automatically upon task completion. Earnings are transferred weekly to your verified bank account or digital wallet.',
                ),
                const SizedBox(height: 14),
                _buildPolicyCard(
                  icon: Icons.verified_user_outlined,
                  title: '4. Safety & Verification Standards',
                  content:
                      'Technicians must maintain valid identity verification documents and comply with local trade regulations and safety standards during customer visits.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.black, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. HELP & CONTACT US SUBVIEW
  // ==========================================
  Widget _buildHelpContactView() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: _backToMain,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Help & Contact Us',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How can we help you?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 14),

                // Contact Channels
                _buildContactChannelTile(
                  icon: Icons.phone_in_talk,
                  title: 'Customer Support Hotline',
                  subtitle: '+1 (800) 555-0199',
                  onTap: () async {
                    final Uri telUri = Uri.parse('tel:+18005550199');
                    if (await canLaunchUrl(telUri)) {
                      await launchUrl(telUri);
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Dialing +1 (800) 555-0199...')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildContactChannelTile(
                  icon: Icons.email_outlined,
                  title: 'Email Support',
                  subtitle: 'support@reapiroo.com',
                  onTap: () async {
                    final Uri mailUri = Uri.parse('mailto:support@reapiroo.com');
                    if (await canLaunchUrl(mailUri)) {
                      await launchUrl(mailUri);
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening mail to support@reapiroo.com...')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildContactChannelTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Live Chat Support',
                  subtitle: 'Available 24/7 in app',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connecting to live support agent...')),
                    );
                  },
                ),

                const SizedBox(height: 24),

                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),

                _buildFaqItem(
                  question: 'How do I receive my weekly earnings?',
                  answer: 'Earnings are automatically processed every Monday for completed tasks and deposited into your linked bank account.',
                ),
                _buildFaqItem(
                  question: 'What if a customer cancels a booking late?',
                  answer: 'If a customer cancels within 1 hour of the scheduled time, a cancellation fee is credited to your balance.',
                ),
                _buildFaqItem(
                  question: 'How can I add new service categories?',
                  answer: 'Go to Bio & Experience > Services tab to select or update your active service skills.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactChannelTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
