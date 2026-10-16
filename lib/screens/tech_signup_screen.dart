import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/services/permission_service.dart';
import 'package:reapiroo/screens/onboarding_screen.dart';
import 'package:reapiroo/screens/role_selection_screen.dart';
import 'package:reapiroo/screens/tech/tech_main_layout.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/services/storage_service.dart';

class TechSignupScreen extends StatefulWidget {
  const TechSignupScreen({super.key});

  @override
  State<TechSignupScreen> createState() => _TechSignupScreenState();
}

class _TechSignupScreenState extends State<TechSignupScreen> {
  int _currentStep = 0;
  final List<String> _steps = ['Personal', 'Services', 'Details', 'Documents'];

  // Form Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String? _selectedGender;
  String? _selectedService;

  // Documents uploaded state tracking (storing local file paths)
  final Map<String, String?> _uploadedDocs = {
    'Profile Picture': null,
    'Emirates ID': null,
    'Other Documents': null,
  };

  final ImagePicker _picker = ImagePicker();

  bool _isApprovalPending = false;

  // Complete List of Offered Services
  final List<Map<String, dynamic>> _serviceOptions = const [
    {'title': 'AC Repair', 'icon': Icons.ac_unit},
    {'title': 'AC Cleaning', 'icon': Icons.mode_fan_off_outlined},
    {'title': 'Plumber', 'icon': Icons.plumbing},
    {'title': 'Electrician', 'icon': Icons.electrical_services},
    {'title': 'Carpenter', 'icon': Icons.handyman_outlined},
    {'title': 'Painter', 'icon': Icons.format_paint},
    {'title': 'Appliances Repair', 'icon': Icons.kitchen},
    {'title': 'Handyman', 'icon': Icons.build},
    {'title': 'Local Movers', 'icon': Icons.local_shipping_outlined},
    {'title': 'Water Tank Cleaning', 'icon': Icons.water_damage_outlined},
    {'title': 'Cleaning', 'icon': Icons.cleaning_services},
    {'title': 'Gardener', 'icon': Icons.yard_outlined},
    {'title': 'Home Services / Maintenance', 'icon': Icons.home_repair_service_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _loadGoogleData();
  }

  Future<void> _loadGoogleData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('google_display_name') ?? '';
    final email = prefs.getString('email') ?? '';
    if (name.isNotEmpty) {
      final parts = name.split(' ');
      setState(() {
        if (_firstNameController.text.isEmpty) {
          _firstNameController.text = parts.first;
        }
        if (parts.length > 1 && _lastNameController.text.isEmpty) {
          _lastNameController.text = parts.sublist(1).join(' ');
        }
      });
    }
    if (email.isNotEmpty) {
      setState(() {
        _emailController.text = email;
      });
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // --- STEP VALIDATION RULES ---

  bool _isStepValid(int stepIndex) {
    switch (stepIndex) {
      case 0: // Personal
        return _firstNameController.text.trim().isNotEmpty &&
            _lastNameController.text.trim().isNotEmpty &&
            _phoneController.text.trim().length >= 10 &&
            _selectedGender != null;
      case 1: // Services
        return _selectedService != null;
      case 2: // Details
        return _bioController.text.trim().isNotEmpty;
      case 3: // Documents (requires at least Profile Picture & Emirates ID)
        return _uploadedDocs['Profile Picture'] != null &&
            _uploadedDocs['Emirates ID'] != null;
      default:
        return false;
    }
  }

  bool get _isCurrentStepValid => _isStepValid(_currentStep);

  Future<void> _saveTechData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawPhone = _phoneController.text.trim();
    final normalizedNumber = rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
    final phoneKey = '92$normalizedNumber';
    final fname = _firstNameController.text.trim();
    final lname = _lastNameController.text.trim();
    final fullName = '$fname $lname'.trim();
    final email = _emailController.text.trim();
    final bio = _bioController.text.trim();
    final gender = _selectedGender;
    final service = _selectedService;

    final googlePhoto = prefs.getString('google_photo_url') ?? '';
    final profilePhoto = prefs.getString('profile_photo_url') ?? googlePhoto;

    await _dbService.saveUserByPhone(
      phoneNumber: phoneKey,
      role: 'tech',
      name: fullName,
      email: email,
      gender: gender,
      details: bio,
      service: service,
      avatarUrl: profilePhoto.isNotEmpty ? profilePhoto : null,
      verified: true,
    );

    await prefs.setString('userRole', 'tech');
    await prefs.setString('tech_firstName', fname);
    await prefs.setString('tech_lastName', lname);
    await prefs.setString('firstName', fname);
    await prefs.setString('lastName', lname);
    await prefs.setString('email', email);
    await prefs.setString('tech_email', email);
    await prefs.setString('tech_bio', bio);
    await prefs.setString('tech_gender', gender ?? '');
    await prefs.setString('gender', gender ?? '');
    await prefs.setString('tech_service', service ?? '');
    await prefs.setString('phoneNumber', phoneKey);
    if (profilePhoto.isNotEmpty) {
      await prefs.setString('profile_photo_url', profilePhoto);
    }

    // Save document paths
    _uploadedDocs.forEach((key, value) async {
      if (value != null) {
        await prefs.setString('tech_doc_$key', value);
      }
    });

    await prefs.setBool('isRegistered', true);
    await prefs.setBool('isLoggedIn', true);
  }

  void _nextStep() {
    if (!_isCurrentStepValid) return;

    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeSignup();
    }
  }

  void _completeSignup() async {
    await _saveTechData();
    setState(() {
      _isApprovalPending = true;
    });

    // Start 3-second timer for redirection
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const TechMainLayout()),
          (route) => false,
        );
      }
    });
  }

  void _navigateToRoleSelection() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isApprovalPending) {
      return _buildApprovalScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 100,
        leading: GestureDetector(
          onTap: _navigateToRoleSelection,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Row(
              children: [
                Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
                SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Step Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: List.generate(_steps.length, (index) {
                  final bool isActive = _currentStep == index;
                  final bool isStepAccessible = _isStepValid(index) || index <= _currentStep;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (isStepAccessible) {
                          setState(() {
                            _currentStep = index;
                          });
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : (isStepAccessible ? Colors.white12 : Colors.transparent),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _steps[index],
                          style: TextStyle(
                            color: isActive
                                ? Colors.black
                                : (isStepAccessible ? Colors.white : Colors.white38),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildCurrentStepContent(),
            ),
          ),
          // Next Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: _isCurrentStepValid ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.grey.shade600,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _currentStep == _steps.length - 1 ? 'Submit' : 'Next',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalStep();
      case 1:
        return _buildServicesStep();
      case 2:
        return _buildDetailsStep();
      case 3:
        return _buildDocumentsStep();
      default:
        return Container();
    }
  }

  Widget _buildPersonalStep() {
    return Column(
      children: [
        const Text(
          'Enter Your Personal Details here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: _buildInputBox(
                controller: _firstNameController,
                hintText: 'First Name',
                icon: Icons.person,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInputBox(
                controller: _lastNameController,
                hintText: 'Last Name',
                icon: Icons.person,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInputBox(
          controller: _emailController,
          hintText: 'Your email',
          icon: Icons.email_outlined,
          readOnly: true,
        ),
        const SizedBox(height: 16),
        _buildInputBox(
          controller: _phoneController,
          hintText: 'Phone Number (e.g. 300 1234567)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const SizedBox(height: 16),
        _buildGenderDropdown(),
      ],
    );
  }

  Widget _buildServicesStep() {
    return Column(
      children: [
        const Text(
          'Select Your Service.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 30),
        ..._serviceOptions.map((service) => _buildServiceCard(
          service['title'] as String,
          service['icon'] as IconData,
        )),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      children: [
        const Text(
          'Write a short bio about yourself',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 40),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: _bioController,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Write Description',
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsStep() {
    return Column(
      children: [
        const Text(
          'Upload Documents',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 30),
        _buildUploadCard('Profile Picture', '(A clear photo of you)'),
        _buildUploadCard('Emirates ID', '( Front and Back )'),
        _buildUploadCard('Other Documents', '(Passport, Visa, If needed )'),
        const SizedBox(height: 20),
        const Text(
          'Please make sure to submit the required things correctly so you don’t delay your approval.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.blueGrey,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            const Text(
              'Pending Approval',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Thank you for registering with Reapiroo. A member of the team will approve your request shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.blueGrey,
                height: 1.4,
              ),
            ),
            const Spacer(),
            Image.asset(
              'assets/images/onb_welcome.png',
              width: MediaQuery.of(context).size.width * 0.7,
            ),
            const Spacer(flex: 2),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Go Home',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildInputBox({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        style: TextStyle(color: readOnly ? Colors.grey.shade700 : Colors.black),
        decoration: InputDecoration(
          icon: Icon(icon, color: readOnly ? Colors.grey : Colors.black, size: 20),
          hintText: hintText,
          hintStyle: TextStyle(color: readOnly ? Colors.grey : Colors.black54, fontWeight: FontWeight.w500),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: _selectedGender,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: const Color(0xFFF8F8F8),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          decoration: const InputDecoration(
            icon: Icon(Icons.transgender, color: Colors.black, size: 20),
            border: InputBorder.none,
            hintText: 'Gender',
            hintStyle: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
          ),
          items: ['Male', 'Female', 'Other'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedGender = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildServiceCard(String title, IconData icon) {
    final bool isSelected = _selectedService == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedService = title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isSelected ? Colors.black : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.black45, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                color: isSelected ? Colors.black : Colors.transparent,
              ),
              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocument(String title) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bool hasPermission = await PermissionService.requestMediaPermission(
        context,
        reason: 'Media access is required to upload verification and certification documents.',
      );
      if (!hasPermission) return;

      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) return;

      final savedPath = await StorageService().compressAndEncodeBase64Bytes(bytes);

      if (title == 'Profile Picture') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_photo_url', savedPath);
      }

      if (mounted) {
        setState(() {
          _uploadedDocs[title] = savedPath;
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text('$title selected successfully!'),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Background upload attempt to Firebase Storage with strict 3-second timeout
      final rawPhone = _phoneController.text.trim();
      final uid = rawPhone.isNotEmpty ? '92$rawPhone' : 'tech_signup_${DateTime.now().millisecondsSinceEpoch}';
      StorageService().uploadVerificationDocumentXFile(
        uid: uid,
        xfile: image,
        fileName: title,
      ).timeout(const Duration(seconds: 3)).then((docUrl) {
        if (docUrl != null && docUrl.startsWith('http') && mounted) {
          setState(() {
            _uploadedDocs[title] = docUrl;
          });
        }
      }).catchError((_) {});

    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to load document: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildUploadCard(String title, String subtitle) {
    final String? filePath = _uploadedDocs[title];
    final bool isUploaded = filePath != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded ? Colors.green.shade400 : Colors.grey.shade200,
          width: isUploaded ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Preview thumbnail when image is uploaded
          if (isUploaded)
            Container(
              width: 46,
              height: 46,
              margin: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: StorageService.getImageProvider(filePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.green.shade50,
                    child: const Icon(
                      Icons.description,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          // Expanded text section to prevent horizontal overflows
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isUploaded)
                      const Padding(
                        padding: EdgeInsets.only(left: 6.0),
                        child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isUploaded ? 'File saved locally' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isUploaded ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Upload / Change Button with fixed padding to save space
          ElevatedButton(
            onPressed: () => _pickDocument(title),
            style: ElevatedButton.styleFrom(
              backgroundColor: isUploaded ? Colors.grey.shade100 : Colors.black,
              foregroundColor: isUploaded ? Colors.black : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(64, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isUploaded ? 'Change' : 'Upload',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}