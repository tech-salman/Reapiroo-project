import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import 'login_signup_screen.dart';
import 'role_selection_screen.dart';
import 'tech/tech_main_layout.dart';
import 'customer/customer_main_layout.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Welcome to',
      description: '',
      image: 'assets/icon/app_icon.png',
      topImage: 'assets/images/onb_welcome.png',
    ),
    OnboardingData(
      title: 'Easy Service Requests',
      description: 'Simply describe your issue with details, photos, or videos. Get personalized offers from nearby technicians within minutes.',
      image: 'assets/images/onb_requests.png',
    ),
    OnboardingData(
      title: 'Choose the Best Offer',
      description: 'Compare offers from multiple technicians and pick the one that fits your needs and budget. No hassle, no guessing!',
      image: 'assets/images/onb_offers.png',
    ),
    OnboardingData(
      title: 'Secure Payments',
      description: 'Pay securely using your preferred method. Your payment is held until the job is completed to your satisfaction.',
      image: 'assets/images/onb_payments.png',
    ),
    OnboardingData(
      title: 'Technicians, Get Ready!',
      description: 'Stay updated with new orders, respond quickly, and grow your wallet with each successful job. Start earning today!',
      image: 'assets/images/onb_tech.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPressed() async {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      final navigator = Navigator.of(context);
      final currentUser = ref.read(currentFirebaseUserProvider);

      if (currentUser != null) {
        final roleAsync = ref.read(userRoleProvider);
        final role = roleAsync.asData?.value ?? '';

        if (role == 'tech' || role == 'technician') {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const TechMainLayout()),
          );
        } else if (role == 'customer') {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const CustomerMainLayout()),
          );
        } else {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
          );
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

        if (isLoggedIn) {
          final String role = prefs.getString('userRole') ?? '';
          if (role == 'tech' || role == 'technician') {
            navigator.pushReplacement(
              MaterialPageRoute(builder: (context) => const TechMainLayout()),
            );
          } else if (role == 'customer') {
            navigator.pushReplacement(
              MaterialPageRoute(builder: (context) => const CustomerMainLayout()),
            );
          } else {
            navigator.pushReplacement(
              MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
            );
          }
        } else {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginSignupScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top Section: Text or Image
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: KeyedSubtree(
                  key: ValueKey<int>(_currentPage),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_pages[_currentPage].title.isNotEmpty)
                        Text(
                          _pages[_currentPage].title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      if (_pages[_currentPage].topImage != null) ...[
                        const SizedBox(height: 8),
                        Image.asset(
                          _pages[_currentPage].topImage!,
                          width: MediaQuery.of(context).size.width * 0.6,
                        ),
                      ],
                      if (_pages[_currentPage].description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          _pages[_currentPage].description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom Section: Fixed Dome and Scrolling Icons
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                // Fixed Black Dome
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(2000),
                      topRight: Radius.circular(2000),
                    ),
                  ),
                ),
                // Scrolling PageView for Icons only
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 60.0),
                        child: Image.asset(
                          _pages[index].image,
                          width: MediaQuery.of(context).size.width * 0.6,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.image, size: 100, color: Colors.white.withValues(alpha: 0.3));
                          },
                        ),
                      ),
                    );
                  },
                ),
                // Indicators and Next Button (Fixed)
                Positioned(
                  bottom: 40,
                  left: 24,
                  right: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(_pages.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? Colors.blue : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      GestureDetector(
                        onTap: _onNextPressed,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 2),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String image;
  final String? topImage;
  final bool isLogoTitle;

  OnboardingData({
    required this.title,
    required this.description,
    required this.image,
    this.topImage,
    this.isLogoTitle = false,
  });
}
