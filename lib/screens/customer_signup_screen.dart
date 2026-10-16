import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/screens/customer/customer_main_layout.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:flutter/services.dart';

class CustomerSignupScreen extends StatefulWidget {
  const CustomerSignupScreen({super.key});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedGender;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadGoogleData();
  }

  Future<void> _loadGoogleData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('google_display_name') ?? '';
    final email = prefs.getString('email') ?? '';
    if (name.isNotEmpty && _nameController.text.isEmpty) {
      setState(() {
        _nameController.text = name;
      });
    }
    if (email.isNotEmpty) {
      setState(() {
        _emailController.text = email;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Section: Black with Curved Bottom
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.elliptical(200, 100),
                  bottomRight: Radius.elliptical(200, 100),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Image.asset(
                    'assets/images/onb_welcome.png',
                    width: MediaQuery.of(context).size.width * 0.6,
                  ),
                  const SizedBox(height: 60),
                  const Text(
                    'Sign up',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Form Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Full Name Field
                    _buildTextField(
                      controller: _nameController,
                      hintText: 'Full name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter your name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Email Field (Read-only / Unchangeable from Google)
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Your email',
                      icon: Icons.email_outlined,
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    // Phone Number Field
                    _buildTextField(
                      controller: _phoneController,
                      hintText: 'Phone Number (e.g. 300 1234567)',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter your phone number';
                        if (value.trim().length < 10) return 'Please enter a valid phone number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Gender Dropdown
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        borderRadius: BorderRadius.circular(16),
                        dropdownColor: const Color(0xFFF8F8F8),
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                        decoration: const InputDecoration(
                          icon: Icon(Icons.transgender, color: Colors.black),
                          border: InputBorder.none,
                          hintText: 'Gender',
                          hintStyle: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
                        ),
                        items: ['Male', 'Female', 'Other']
                            .map((label) => DropdownMenuItem(
                          value: label,
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                        validator: (value) => value == null ? 'Please select gender' : null,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final navigator = Navigator.of(context);
                            final prefs = await SharedPreferences.getInstance();
                            final rawPhone = _phoneController.text.trim();
                            final normalizedNumber = rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
                            final phoneKey = '92$normalizedNumber';
                            final fullName = _nameController.text.trim();
                            final email = _emailController.text.trim();

                            final googlePhoto = prefs.getString('google_photo_url') ?? '';
                            final profilePhoto = prefs.getString('profile_photo_url') ?? googlePhoto;

                            await _dbService.saveUserByPhone(
                              phoneNumber: phoneKey,
                              role: 'customer',
                              name: fullName,
                              email: email,
                              gender: _selectedGender,
                              avatarUrl: profilePhoto.isNotEmpty ? profilePhoto : null,
                              verified: true,
                            );

                            final nameParts = fullName.split(' ');
                            final firstName = nameParts.isNotEmpty ? nameParts.first : '';
                            final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

                            await prefs.setString('userRole', 'customer');
                            await prefs.setString('cust_firstName', firstName);
                            await prefs.setString('cust_lastName', lastName);
                            await prefs.setString('firstName', firstName);
                            await prefs.setString('lastName', lastName);
                            await prefs.setString('email', email);
                            await prefs.setString('cust_email', email);
                            await prefs.setString('cust_gender', _selectedGender ?? '');
                            await prefs.setString('gender', _selectedGender ?? '');
                            await prefs.setString('phoneNumber', phoneKey);
                            await prefs.setBool('isLoggedIn', true);
                            await prefs.setBool('isRegistered', true);
                            if (profilePhoto.isNotEmpty) {
                              await prefs.setString('profile_photo_url', profilePhoto);
                            }
                            
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const CustomerMainLayout()),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(color: Colors.black, fontSize: 13, height: 1.5),
                        children: [
                          TextSpan(text: 'By signing up you agree to our '),
                          TextSpan(
                            text: 'Terms of Services',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '\nand '),
                          TextSpan(
                            text: 'Privacy Policy.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        readOnly: readOnly,
        style: TextStyle(color: readOnly ? Colors.grey.shade700 : Colors.black),
        decoration: InputDecoration(
          icon: Icon(icon, color: readOnly ? Colors.grey : Colors.black),
          hintText: hintText,
          hintStyle: TextStyle(color: readOnly ? Colors.grey : Colors.black54, fontWeight: FontWeight.w500),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
