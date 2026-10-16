import 'package:flutter/material.dart';
import 'package:reapiroo/screens/customer/customer_wallet_screen.dart';
import 'package:reapiroo/screens/customer/customer_notification_screen.dart';
import 'package:reapiroo/screens/customer/customer_task_description_screen.dart';
import 'package:reapiroo/widgets/customer_drawer.dart';
import 'package:reapiroo/widgets/service_card.dart';
import 'package:reapiroo/widgets/notification_bell_button.dart';
import 'package:reapiroo/widgets/app_info_cards_scroll_view.dart';

class ServiceItem {
  final String name;
  final String imageUrl;

  const ServiceItem({required this.name, required this.imageUrl});
}

class CustomerHomeScreen extends StatefulWidget {
  final bool embedInShell;

  const CustomerHomeScreen({
    super.key,
    this.embedInShell = false,
  });

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  bool _showAllServices = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedServiceForTask;
  String? _selectedServiceImageUrl;

  final List<ServiceItem> _allServices = const [
    ServiceItem(
      name: 'AC Repair',
      imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'AC Cleaning',
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Plumber',
      imageUrl: 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Electrician',
      imageUrl: 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Carpenter',
      imageUrl: 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Painter',
      imageUrl: 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Appliances Repair',
      imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Handyman',
      imageUrl: 'https://images.unsplash.com/photo-1505798577917-a65157d3320a?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Local Movers',
      imageUrl: 'https://images.unsplash.com/photo-1600518464441-9154a4dea21b?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Water Tank Cleaning',
      imageUrl: 'https://images.unsplash.com/photo-1507652313519-d4e9174996dd?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Cleaning',
      imageUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Gardener',
      imageUrl: 'https://images.unsplash.com/photo-1558904541-efa843a96f01?w=500&auto=format&fit=crop&q=60',
    ),
    ServiceItem(
      name: 'Home Services / Maintenance',
      imageUrl: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=500&auto=format&fit=crop&q=60',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ServiceItem> get _displayedServices {
    List<ServiceItem> list = _allServices;
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (!_showAllServices && _searchQuery.isEmpty) {
      return list.take(4).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedServiceForTask != null) {
      Widget taskScreen = CustomerTaskDescriptionScreen(
        serviceName: _selectedServiceForTask!,
        imageUrl: _selectedServiceImageUrl,
        embedInShell: true,
        onBackPressed: () {
          setState(() {
            _selectedServiceForTask = null;
            _selectedServiceImageUrl = null;
          });
        },
      );

      if (widget.embedInShell) {
        return taskScreen;
      }

      return Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        drawer: const CustomerDrawer(),
        body: SafeArea(child: taskScreen),
      );
    }

    final displayedList = _displayedServices;

    Widget mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () {
                    Scaffold.of(ctx).openDrawer();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.menu, color: Colors.white, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                            });
                          },
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search for anything',
                            hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          child: const Icon(Icons.close, color: Colors.white70, size: 16),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 38,
                height: 38,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.credit_card, color: Colors.black, size: 22),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CustomerWalletScreen()),
                    );
                  },
                ),
              ),
              NotificationBellButton(
                isTech: false,
                backgroundColor: Colors.transparent,
                iconColor: Colors.black,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CustomerNotificationScreen()),
                  );
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=80'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.65),
                            Colors.transparent,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ultimate Guide to\nApp Advertising',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const AppInfoCardsScrollView(),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchQuery.isNotEmpty ? 'Search Results' : 'Top Services',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (_searchQuery.isEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showAllServices = !_showAllServices;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _showAllServices ? 'Show less' : 'View all',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (displayedList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No services found for "$_searchQuery"',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: displayedList.length,
                    itemBuilder: (context, index) {
                      final item = displayedList[index];
                      return ServiceCard(
                        label: item.name,
                        imageUrl: item.imageUrl,
                        onTap: () {
                          setState(() {
                            _selectedServiceForTask = item.name;
                            _selectedServiceImageUrl = item.imageUrl;
                          });
                        },
                      );
                    },
                  ),
                // Bottom padding to clear the curved nav bar floating above
                const SizedBox(height: 110),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedInShell) {
      return mainContent;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      drawer: const CustomerDrawer(),
      body: SafeArea(child: mainContent),
    );
  }

  Widget _buildSmallCard(String title, String date, IconData icon, String text) {
    return Container();
  }

}
