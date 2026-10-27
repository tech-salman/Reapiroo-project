import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_wallet_screen.dart';
import 'customer_notification_screen.dart';
import 'customer_task_description_screen.dart';
import '../../widgets/customer_drawer.dart';
import '../../widgets/service_card.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/app_info_cards_scroll_view.dart';

class ServiceItem {
  final String name;
  final String imageUrl;

  const ServiceItem({required this.name, required this.imageUrl});
}

class CustomerSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  const CustomerSearchBar({
    super.key,
    required this.onChanged,
    required this.onCleared,
  });

  @override
  State<CustomerSearchBar> createState() => _CustomerSearchBarState();
}

class _CustomerSearchBarState extends State<CustomerSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              controller: _controller,
              onChanged: (val) {
                setState(() {
                  _hasText = val.trim().isNotEmpty;
                });
                widget.onChanged(val.trim());
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
          if (_hasText)
            GestureDetector(
              onTap: () {
                _controller.clear();
                setState(() {
                  _hasText = false;
                });
                widget.onCleared();
              },
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
        ],
      ),
    );
  }
}

class CustomerHeaderBar extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onWalletPressed;
  final VoidCallback onNotificationPressed;

  const CustomerHeaderBar({
    super.key,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onWalletPressed,
    required this.onNotificationPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: CustomerSearchBar(
              onChanged: onSearchChanged,
              onCleared: onSearchCleared,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 38,
            height: 38,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.credit_card, color: Colors.black, size: 22),
              onPressed: onWalletPressed,
            ),
          ),
          NotificationBellButton(
            isTech: false,
            backgroundColor: Colors.transparent,
            iconColor: Colors.black,
            onPressed: onNotificationPressed,
          ),
        ],
      ),
    );
  }
}

class CustomerBannerWidget extends StatelessWidget {
  const CustomerBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
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
    );
  }
}

class CustomerServicesGridWidget extends StatelessWidget {
  final List<ServiceItem> displayedList;
  final String searchQuery;
  final bool showAllServices;
  final VoidCallback onToggleShowAll;
  final ValueChanged<ServiceItem> onServiceSelected;

  const CustomerServicesGridWidget({
    super.key,
    required this.displayedList,
    required this.searchQuery,
    required this.showAllServices,
    required this.onToggleShowAll,
    required this.onServiceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              searchQuery.isNotEmpty ? 'Search Results' : 'Top Services',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (searchQuery.isEmpty)
              GestureDetector(
                onTap: onToggleShowAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    showAllServices ? 'Show less' : 'View all',
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
                  'No services found for "$searchQuery"',
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
                onTap: () => onServiceSelected(item),
              );
            },
          ),
      ],
    );
  }
}

class CustomerHomeScreen extends ConsumerStatefulWidget {
  final bool embedInShell;

  const CustomerHomeScreen({
    super.key,
    this.embedInShell = false,
  });

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  bool _showAllServices = false;
  String _searchQuery = '';
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
        CustomerHeaderBar(
          onSearchChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          onSearchCleared: () {
            setState(() {
              _searchQuery = '';
            });
          },
          onWalletPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CustomerWalletScreen()),
            );
          },
          onNotificationPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CustomerNotificationScreen()),
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CustomerBannerWidget(),
                const SizedBox(height: 16),
                const AppInfoCardsScrollView(),
                const SizedBox(height: 20),
                CustomerServicesGridWidget(
                  displayedList: displayedList,
                  searchQuery: _searchQuery,
                  showAllServices: _showAllServices,
                  onToggleShowAll: () {
                    setState(() {
                      _showAllServices = !_showAllServices;
                    });
                  },
                  onServiceSelected: (item) {
                    setState(() {
                      _selectedServiceForTask = item.name;
                      _selectedServiceImageUrl = item.imageUrl;
                    });
                  },
                ),
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
}
