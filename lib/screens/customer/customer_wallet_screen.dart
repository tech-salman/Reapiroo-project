import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/services/payment_and_transaction_service.dart';

class CustomerWalletScreen extends StatefulWidget {
  const CustomerWalletScreen({super.key});

  @override
  State<CustomerWalletScreen> createState() => _CustomerWalletScreenState();
}

class CustomerTransactionItem {
  final String title;
  final String subtitle;
  final String amount;
  final bool isCredit;
  final String dateGroup;

  const CustomerTransactionItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.dateGroup,
  });
}

class _CustomerWalletScreenState extends State<CustomerWalletScreen> {
  bool _isLoading = true;
  double _availableBalance = 0.00;
  List<CustomerTransactionItem> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadCustomerWallet();
  }

  Future<void> _loadCustomerWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ??
        prefs.getString('phoneNumber') ??
        prefs.getString('email') ??
        '';

    if (uid.isNotEmpty) {
      DatabaseService().streamUserProfile(uid).listen((snap) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final bal = (data['walletBalance'] as num?)?.toDouble() ??
              ((data['balanceDetails'] as Map<String, dynamic>?)?['currentBalance'] as num?)?.toDouble() ??
              0.0;
          if (mounted) {
            setState(() {
              _availableBalance = bal;
              _isLoading = false;
            });
          }
        }
      });

      PaymentAndTransactionService().fetchUserTransactions(uid).listen((txList) {
        final loaded = txList.map((tx) {
          final isCredit = tx.paymentMethod == 'top_up' || tx.customerId == uid;
          final title = isCredit ? 'Wallet Balance' : 'Service Payment';
          final subtitle = tx.paymentMethod.replaceAll('_', ' ').toUpperCase();
          final amountStr = '${tx.amount.toStringAsFixed(0)} AED';
          return CustomerTransactionItem(
            title: title,
            subtitle: subtitle,
            amount: amountStr,
            isCredit: isCredit,
            dateGroup: 'Recent Transactions',
          );
        }).toList();

        if (mounted) {
          setState(() {
            _transactions = loaded;
          });
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _availableBalance = 0.0;
          _isLoading = false;
        });
      }
    }
  }

  void _showAddMoneyDialog() {
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
                  'Add Money',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Enter Amount (AED)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 8),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 100',
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final input = double.tryParse(amountController.text.trim());
                          if (input != null && input > 0) {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(dialogContext);

                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              await DatabaseService().topUpCustomerBalance(uid, input, 'card');
                            }

                            messenger.showSnackBar(
                              SnackBar(content: Text('Added ${input.toStringAsFixed(2)} AED to your wallet!')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Add', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5E5EA),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddNewCardDialog() {
    final TextEditingController cardNumberController = TextEditingController();
    final TextEditingController holderController = TextEditingController();

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
                  'Add New Card',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Card Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: TextField(
                  controller: cardNumberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '**** **** **** 4242',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Cardholder Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: TextField(
                  controller: holderController,
                  decoration: const InputDecoration(
                    hintText: 'Full Name',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('New Card added successfully!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Save Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5E5EA),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Wallet',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Available Balance Card (Light Grey Card with Curved Abstract Design)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBEBEB),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: CustomPaint(
                            painter: _CurvedBackgroundPainter(),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Available Balance',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_availableBalance.toStringAsFixed(2)} AED',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Black Action Pill Box inside Balance Card
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        // Add Money Button
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: _showAddMoneyDialog,
                                            behavior: HitTestBehavior.opaque,
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Add Money',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // History Button
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Viewing Wallet History')),
                                              );
                                            },
                                            behavior: HitTestBehavior.opaque,
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  'History',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Add New Card Button
                      GestureDetector(
                        onTap: _showAddNewCardDialog,
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
                              SizedBox(width: 14),
                              Text(
                                'Add New Card',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Transactions Section
                      const Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Grouped Transactions
                      ..._buildGroupedTransactions(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedTransactions() {
    final Map<String, List<CustomerTransactionItem>> groups = {};

    for (var item in _transactions) {
      groups.putIfAbsent(item.dateGroup, () => []).add(item);
    }

    final List<Widget> widgets = [];

    groups.forEach((groupName, items) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
          child: Text(
            groupName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      );

      for (var item in items) {
        widgets.add(_buildTransactionTile(item));
      }

      widgets.add(const SizedBox(height: 12));
    });

    return widgets;
  }

  Widget _buildTransactionTile(CustomerTransactionItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          // Black Circular Icon with White Arrow
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.isCredit ? Icons.arrow_downward : Icons.arrow_forward,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Right Amount Text
          Text(
            item.amount,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the curved abstract shapes inside the light grey balance card
class _CurvedBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22.0;

    // Top Right Arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 0.95, size.height * 0.05), radius: 70),
      0,
      3.14,
      false,
      paint,
    );

    // Bottom Left Arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 0.05, size.height * 0.85), radius: 80),
      3.14 / 2,
      3.14,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
