import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/wallet_provider.dart';
import '../../providers/services_providers.dart';
import '../../providers/auth_provider.dart';

class TechWalletScreen extends ConsumerStatefulWidget {
  const TechWalletScreen({super.key});

  @override
  ConsumerState<TechWalletScreen> createState() => _TechWalletScreenState();
}

class TransactionItem {
  final String title;
  final String subtitle;
  final String amount;
  final bool isCredit;
  final String dateGroup;

  const TransactionItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.dateGroup,
  });
}

class _TechWalletScreenState extends ConsumerState<TechWalletScreen> {
  bool _hasSavedWallet = false;

  // Wallet Bank Details State
  String _selectedBank = 'ADCB';
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();

  final List<String> _bankOptions = const [
    'ADCB',
    'Emirates NBD',
    'Dubai Islamic Bank',
    'Mashreq Bank',
    'First Abu Dhabi Bank',
    'RAKBANK',
  ];

  @override
  void initState() {
    super.initState();
    _checkSavedWallet();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ibanController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedWallet() async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user != null) {
      try {
        final dbService = ref.read(databaseServiceProvider);
        final doc = await dbService.getTechProfile(user.uid);
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final bankDetails = data['bankDetails'] as Map<String, dynamic>?;
          if (bankDetails != null) {
            setState(() {
              _selectedBank = bankDetails['bankName'] as String? ?? 'ADCB';
              _fullNameController.text = bankDetails['fullName'] as String? ?? '';
              _ibanController.text = bankDetails['iban'] as String? ?? '';
              _accountNumberController.text = bankDetails['accountNumber'] as String? ?? '';
              _hasSavedWallet = _ibanController.text.isNotEmpty;
            });
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _saveBankDetails() async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;

    final fullName = _fullNameController.text.trim();
    final iban = _ibanController.text.trim();
    final accountNumber = _accountNumberController.text.trim();

    if (fullName.isEmpty || iban.isEmpty || accountNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all bank detail fields.')),
      );
      return;
    }

    try {
      final dbService = ref.read(databaseServiceProvider);
      final bankMap = {
        'bankName': _selectedBank,
        'fullName': fullName,
        'iban': iban,
        'accountNumber': accountNumber,
      };

      await dbService.updateTechProfile(user.uid, {'bankDetails': bankMap});

      setState(() {
        _hasSavedWallet = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account details saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save bank details: $e')),
        );
      }
    }
  }

  void _showWithdrawDialog(double availableBalance) {
    if (!_hasSavedWallet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save your bank details first before withdrawing.')),
      );
      return;
    }

    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Withdraw Funds',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Available to withdraw: ${availableBalance.toStringAsFixed(2)} AED',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    prefixText: 'AED ',
                    prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = amountController.text.trim();
                    final amount = double.tryParse(text) ?? 0.0;
                    if (amount > 0 && amount <= availableBalance) {
                      Navigator.pop(dialogContext);
                      // Record withdrawal transaction
                      final user = ref.read(currentFirebaseUserProvider);
                      if (user != null) {
                        await ref.read(walletControllerProvider.notifier).recordTransaction(
                          bookingId: 'withdrawal_${DateTime.now().millisecondsSinceEpoch}',
                          customerId: '',
                          technicianId: user.uid,
                          amount: amount,
                          paymentMethod: 'bank_withdrawal',
                          paymentStatus: 'processed',
                        );
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Successfully requested withdrawal of ${amount.toStringAsFixed(2)} AED!')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid withdrawal amount.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Confirm Withdrawal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    final balance = ref.watch(walletBalanceProvider);
    final txAsync = ref.watch(walletTransactionsProvider);
    final transactions = txAsync.asData?.value ?? [];

    final transactionItems = transactions.map((tx) {
      final isCredit = tx.technicianId.isNotEmpty && tx.amount > 0;
      final title = isCredit ? 'Job Earnings' : 'Withdrawal';
      final subtitle = tx.paymentMethod.replaceAll('_', ' ').toUpperCase();
      final amountStr = '${tx.amount.toStringAsFixed(0)} AED';
      return TransactionItem(
        title: title,
        subtitle: subtitle,
        amount: amountStr,
        isCredit: isCredit,
        dateGroup: 'Recent Transactions',
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Wallet & Earnings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Earnings',
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${balance.toStringAsFixed(2)} AED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _showWithdrawDialog(balance),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Withdraw Funds',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Bank Account Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedBank,
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: const Color(0xFFF8F8F8),
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      border: OutlineInputBorder(),
                    ),
                    items: _bankOptions.map((bank) => DropdownMenuItem(value: bank, child: Text(bank))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBank = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name as on Account',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ibanController,
                    decoration: const InputDecoration(
                      labelText: 'IBAN Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _accountNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveBankDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _hasSavedWallet ? 'Update Bank Details' : 'Save Bank Details',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Earnings History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            if (transactionItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No earnings history yet.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactionItems.length,
                itemBuilder: (context, index) {
                  final item = transactionItems[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: item.isCredit ? Colors.green.shade50 : Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: item.isCredit ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${item.isCredit ? '+' : '-'}${item.amount}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: item.isCredit ? Colors.green : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
