import 'package:flutter/material.dart';

class TechWalletSummarySection extends StatelessWidget {
  final double balance;
  final int todayAppointmentsCount;
  final int happyCustomersCount;
  final int jobsCompletedCount;
  final VoidCallback onViewWalletPressed;

  const TechWalletSummarySection({
    super.key,
    required this.balance,
    required this.todayAppointmentsCount,
    required this.happyCustomersCount,
    required this.jobsCompletedCount,
    required this.onViewWalletPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Wallet Balance',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              GestureDetector(
                onTap: onViewWalletPressed,
                child: const Text(
                  'View Wallet ->',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${balance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Appointments', '$todayAppointmentsCount'),
              _buildStatItem('Happy Clients', '$happyCustomersCount'),
              _buildStatItem('Jobs Done', '$jobsCompletedCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}
