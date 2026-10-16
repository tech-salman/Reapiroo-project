import 'package:flutter/material.dart';

class InfoCardItem {
  final String title;
  final String date;
  final IconData icon;
  final String text;
  final String fullDetails;

  const InfoCardItem({
    required this.title,
    required this.date,
    required this.icon,
    required this.text,
    required this.fullDetails,
  });
}

class AppInfoCardsScrollView extends StatelessWidget {
  final List<InfoCardItem>? customCards;

  const AppInfoCardsScrollView({super.key, this.customCards});

  static const List<InfoCardItem> defaultCards = [
    InfoCardItem(
      title: 'Announcement',
      date: 'Today',
      icon: Icons.campaign,
      text: 'Welcome to Reapiroo Service Platform! Book or provide verified home maintenance services with live tracking and instant bidding.',
      fullDetails: 'Welcome to Reapiroo! Our platform connects customers directly with certified, background-checked home maintenance technicians across the region. Enjoy real-time job tracking, transparent instant bidding, secure escrow payments, and live chat support for all your home repair, cleaning, AC maintenance, plumbing, electrical, and handyman needs.',
    ),
    InfoCardItem(
      title: 'New Offer',
      date: 'Active',
      icon: Icons.percent,
      text: 'Get 10% cash back in your Reapiroo wallet balance on your first booking or completed service payment!',
      fullDetails: 'Take advantage of our launch promotion! Every customer receives 10% cash back credited directly to their Reapiroo wallet balance upon completing their first home service booking. Cash back can be applied instantly toward future maintenance jobs, spare parts purchases, or tipping technicians.',
    ),
    InfoCardItem(
      title: 'Platform Verified',
      date: 'Secure',
      icon: Icons.verified_user,
      text: 'All Reapiroo technicians and customers undergo strict verification for safe and reliable home maintenance.',
      fullDetails: 'Safety and trust are our top priorities at Reapiroo. Every technician on our network undergoes rigorous identity verification, criminal background checks, and professional skill assessments. Similarly, customer accounts are verified via phone and email to ensure a secure, respectful, and reliable marketplace environment for everyone.',
    ),
    InfoCardItem(
      title: 'Promo Rewards',
      date: 'Bonus',
      icon: Icons.card_giftcard,
      text: 'Refer friends to Reapiroo and earn service discounts and wallet credits on every successful home repair job.',
      fullDetails: 'Share the convenience of Reapiroo with your friends and family! Use your unique referral link from your profile to invite friends. When they complete their first home service booking, both you and your friend receive exclusive wallet credits and service discounts automatically applied to your accounts.',
    ),
    InfoCardItem(
      title: 'System Status',
      date: 'Online',
      icon: Icons.bolt,
      text: 'Real-time dispatching, live chat support, and instant escrow payment transactions are fully operational.',
      fullDetails: 'Our cloud-powered dispatch and matching engine operates 24/7 to connect your service requests with nearby available technicians instantly. All chat threads, live location tracking on maps, wallet balances, and bank payout transactions are secured with end-to-end encryption and monitored continuously.',
    ),
  ];

  void _showCardDetailsDialog(BuildContext context, InfoCardItem card) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(card.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.date,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE5E5EA), height: 1),
              const SizedBox(height: 16),
              Text(
                card.fullDetails,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = customCards ?? defaultCards;

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final card = cards[index];
          return GestureDetector(
            onTap: () => _showCardDetailsDialog(context, card),
            child: Container(
              width: 195,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(card.icon, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (card.date.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          card.date,
                          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 9),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      card.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 9.5,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
