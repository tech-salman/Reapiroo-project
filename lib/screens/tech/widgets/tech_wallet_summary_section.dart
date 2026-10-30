import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';

class TechWalletSummarySection extends ConsumerWidget {
  final double? balance;
  final int todayAppointmentsCount;
  final int happyCustomersCount;
  final int jobsCompletedCount;
  final VoidCallback onViewWalletPressed;

  const TechWalletSummarySection({
    super.key,
    this.balance,
    required this.todayAppointmentsCount,
    required this.happyCustomersCount,
    required this.jobsCompletedCount,
    required this.onViewWalletPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileStreamProvider).asData?.value;
    final liveBalance = profile?.walletBalance ?? balance ?? 0.0;
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${liveBalance.toStringAsFixed(2)} AED',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildStatItem('Appointments', '$todayAppointmentsCount')),
              Expanded(child: _buildStatItem('Happy Clients', '$happyCustomersCount')),
              Expanded(child: _buildStatItem('Jobs Done', '$jobsCompletedCount')),
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
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}
