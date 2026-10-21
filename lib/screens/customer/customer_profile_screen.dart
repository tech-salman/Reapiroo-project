import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reapiroo/providers/services_providers.dart';
import 'package:reapiroo/services/storage_service.dart';
import 'package:reapiroo/screens/onboarding_screen.dart';
import 'package:reapiroo/screens/customer/customer_main_layout.dart';
import 'package:reapiroo/screens/customer/customer_wallet_screen.dart';

enum CustomerProfileSubView {
  main,
  generalInfo,
  savedAddress,
  termsPolicy,
  helpSupport,
}

class CustomerProfileScreen extends ConsumerStatefulWidget {
  final bool embedInShell;

  const CustomerProfileScreen({
    super.key,
    this.embedInShell = false,
  });

  @override
  ConsumerState<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class AddressItem {
  final String label;
  final String fullAddress;
  final bool isDefault;

  const AddressItem({
    required this.label,
    required this.fullAddress,
    this.isDefault = false,
  });
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  CustomerProfileSubView _activeView = CustomerProfileSubView.main;

  // General Information Form Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedGender;
  String _profilePhotoUrl = '';

  // Saved Address Form & List
  final List<AddressItem> _addresses = [];

  final TextEditingController _addressLabelController = TextEditingController();
  final TextEditingController _addressTextController = TextEditingController();

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
          await dbService.updateCustomerProfile(phoneKey, {'avatarUrl': uploadedUrl});
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

    final phoneKey = prefs.getString('phoneNumber') ?? firebaseUser?.phoneNumber ?? '';
    final uid = firebaseUser?.uid ?? '';
    final dbService = ref.read(databaseServiceProvider);

    // 1. Try Firestore fetch
    DocumentSnapshot<Map<String, dynamic>>? doc;
    if (uid.isNotEmpty) {
      try {
        final snap = await dbService.getCustomerProfile(uid);
        if (snap.exists && snap.data() != null) doc = snap;
      } catch (_) {}
    }
    if (doc == null && phoneKey.isNotEmpty) {
      try {
        final snap = await dbService.getCustomerProfile(phoneKey);
        if (snap.exists && snap.data() != null) doc = snap;
      } catch (_) {}
    }

    if (doc != null && doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final name = data['name'] as String? ?? data['fullName'] as String? ?? '';
      final email = data['email'] as String? ?? '';
      final phone = (data['phoneNumber'] as String? ?? data['phone'] as String?) ?? phoneKey;
      final gender = data['gender'] as String? ?? '';
      final avatar = data['avatarUrl'] as String? ?? data['profilePictureUrl'] as String? ?? '';

      final rawAddresses = data['savedAddresses'] as List<dynamic>?;
      if (rawAddresses != null) {
        _addresses.clear();
        for (var item in rawAddresses) {
          if (item is Map) {
            _addresses.add(AddressItem(
              label: item['label'] ?? 'Home',
              fullAddress: item['fullAddress'] ?? '',
              isDefault: item['isDefault'] ?? false,
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
        if (avatar.isNotEmpty) _profilePhotoUrl = avatar; else _profilePhotoUrl = photoToUse;
        if (['Male', 'Female', 'Other'].contains(gender)) {
          _selectedGender = gender;
        }
      });
      return;
    }

    // 2. Fallback to SharedPreferences
    if (!mounted) return;

    var fname = prefs.getString('cust_firstName') ?? prefs.getString('firstName') ?? '';
    var lname = prefs.getString('cust_lastName') ?? prefs.getString('lastName') ?? '';

    if (lname.isEmpty && fname.contains(' ')) {
      final parts = fname.split(' ');
      fname = parts.first;
      lname = parts.sublist(1).join(' ');
    }

    final email = prefs.getString('cust_email') ?? prefs.getString('email') ?? firebaseUser?.email ?? '';
    final phone = prefs.getString('phoneNumber') ?? firebaseUser?.phoneNumber ?? '';
    final gender = prefs.getString('cust_gender') ?? prefs.getString('gender') ?? '';

    setState(() {
      _profilePhotoUrl = photoToUse;
      _firstNameController.text = fname;
      _lastNameController.text = lname;
      _emailController.text = email;
      _phoneController.text = phone;
      if (['Male', 'Female', 'Other'].contains(gender)) {
        _selectedGender = gender;
      }
    });
  }

  Future<void> _saveAddressesToBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneKey = prefs.getString('phoneNumber');
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      final dbService = ref.read(databaseServiceProvider);

      final addressesData = _addresses.map((a) => {
        'label': a.label,
        'fullAddress': a.fullAddress,
        'isDefault': a.isDefault,
      }).toList();

      await prefs.setString('customer_saved_addresses_json', json.encode(addressesData));

      if (uid != null && uid.isNotEmpty) {
        await dbService.updateCustomerProfile(uid, {'savedAddresses': addressesData});
      }
      if (phoneKey != null && phoneKey.isNotEmpty) {
        await dbService.updateCustomerProfile(phoneKey, {'savedAddresses': addressesData});
      }
    } catch (_) {}
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneKey = prefs.getString('phoneNumber');
    if (phoneKey == null || phoneKey.isEmpty) return;

    final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
    final email = _emailController.text.trim();
    final dbService = ref.read(databaseServiceProvider);

    try {
      await dbService.updateCustomerProfile(phoneKey, {
        'name': fullName,
        'email': email,
        'gender': _selectedGender,
      });
    } catch (_) {}

    await prefs.setString('cust_firstName', _firstNameController.text.trim());
    await prefs.setString('cust_lastName', _lastNameController.text.trim());
    await prefs.setString('cust_email', email);
    await prefs.setString('cust_gender', _selectedGender ?? '');
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
    _addressLabelController.dispose();
    _addressTextController.dispose();
    super.dispose();
  }

  void _navigateToSubView(CustomerProfileSubView subView) {
    setState(() {
      _activeView = subView;
    });
  }

  void _backToMain() {
    setState(() {
      _activeView = CustomerProfileSubView.main;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedInShell) {
      return const CustomerMainLayout(initialIndex: 3);
    }

    return PopScope(
      canPop: _activeView == CustomerProfileSubView.main,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _activeView != CustomerProfileSubView.main) {
          _backToMain();
        }
      },
      child: _buildActiveBodyContent(),
    );
  }

  Widget _buildActiveBodyContent() {
    switch (_activeView) {
      case CustomerProfileSubView.main:
        return _buildMainProfileView();
      case CustomerProfileSubView.generalInfo:
        return _buildGeneralInfoView();
      case CustomerProfileSubView.savedAddress:
        return _buildSavedAddressView();
      case CustomerProfileSubView.termsPolicy:
        return _buildTermsPolicyView();
      case CustomerProfileSubView.helpSupport:
        return _buildHelpSupportView();
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
                // Settings Gear Icon
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
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // User Avatar & Name
          CircleAvatar(
            radius: 64,
            backgroundImage: StorageService.getImageProvider(_avatarImage),
            backgroundColor: Colors.grey,
          ),
          const SizedBox(height: 14),
          Text(
            displayName.isEmpty ? 'Customer' : displayName,
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
            title: 'General Information',
            isHighlighted: true,
            onTap: () => _navigateToSubView(CustomerProfileSubView.generalInfo),
          ),
          _buildMenuTile(
            icon: Icons.business_center,
            title: 'Saved Address',
            onTap: () => _navigateToSubView(CustomerProfileSubView.savedAddress),
          ),
          _buildMenuTile(
            icon: Icons.credit_card,
            title: 'Wallet',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CustomerWalletScreen()),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.shield_outlined,
            title: 'Terms/Policy',
            onTap: () => _navigateToSubView(CustomerProfileSubView.termsPolicy),
          ),
          _buildMenuTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () => _navigateToSubView(CustomerProfileSubView.helpSupport),
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
  // 2. GENERAL INFORMATION SUBVIEW
  // ==========================================
  Widget _buildGeneralInfoView() {
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
                'General Information',
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

                // Phone Input
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
                        const SnackBar(content: Text('General information saved!')),
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
  // 3. SAVED ADDRESS SUBVIEW
  // ==========================================
  Widget _buildSavedAddressView() {
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
                'Saved Addresses',
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
                ..._addresses.map((addr) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9FB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on_outlined, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      addr.label,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                    if (addr.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('Default', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  addr.fullAddress,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 20),

                // Add New Address Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add New Address',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _addressLabelController,
                          decoration: const InputDecoration(
                            hintText: 'Address Label (e.g. Home, Work)',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _addressTextController,
                          decoration: const InputDecoration(
                            hintText: 'Full Address Details',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final label = _addressLabelController.text.trim();
                            final fullText = _addressTextController.text.trim();
                            if (label.isEmpty || fullText.isEmpty) return;

                            setState(() {
                              _addresses.add(AddressItem(label: label, fullAddress: fullText));
                              _addressLabelController.clear();
                              _addressTextController.clear();
                            });
                            await _saveAddressesToBackend();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('New address added!')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
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
  // 4. TERMS & POLICY SUBVIEW
  // ==========================================
  Widget _buildTermsPolicyView() {
    return Column(
      children: [
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
                _buildPolicyCard('1. Customer Terms of Service', 'Reapiroo connects customers with verified, trained service technicians. All booking requests are processed securely through the platform.'),
                const SizedBox(height: 12),
                _buildPolicyCard('2. Privacy & Security', 'Your address, phone number, and booking details are strictly protected and shared only with assigned technicians during active jobs.'),
                const SizedBox(height: 12),
                _buildPolicyCard('3. Cancellation & Refunds', 'Cancellations made 1+ hour prior to job time are free of charge. Late cancellations may incur a nominal scheduling fee.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyCard(String title, String content) {
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
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black87)),
        ],
      ),
    );
  }

  // ==========================================
  // 5. HELP & SUPPORT SUBVIEW
  // ==========================================
  Widget _buildHelpSupportView() {
    return Column(
      children: [
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
                'Help & Support',
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
                _buildHelpOptionTile(Icons.phone, 'Call Customer Care', '+1 (800) 555-0199', () async {
                  final uri = Uri.parse('tel:+18005550199');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }),
                const SizedBox(height: 12),
                _buildHelpOptionTile(Icons.email, 'Email Customer Support', 'support@reapiroo.com', () async {
                  final uri = Uri.parse('mailto:support@reapiroo.com');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }),
                const SizedBox(height: 12),
                _buildHelpOptionTile(Icons.chat, 'Live Chat with Support', '24/7 Assistance', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening live chat with support agent...')),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpOptionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
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
          height: 40,
          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
      ),
    );
  }
}
