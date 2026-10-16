import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/services/payment_and_transaction_service.dart';

class TechWalletScreen extends StatefulWidget {
  const TechWalletScreen({super.key});

  @override
  State<TechWalletScreen> createState() => _TechWalletScreenState();
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

class _TechWalletScreenState extends State<TechWalletScreen> {
  bool _isLoading = true;
  bool _hasSavedWallet = false;

  // Wallet Bank Details State
  String _selectedBank = 'ADCB';
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();

  // Balance & Transactions State
  double _totalBalance = 0.00;
  double _pendingBalance = 0.00;
  double _availableBalance = 0.00;

  String _canonicalTechId = '';
  StreamSubscription? _profileSub;
  StreamSubscription? _transactionSub;

  final List<String> _bankOptions = const [
    'ADCB',
    'Emirates NBD',
    'Dubai Islamic Bank',
    'Mashreq Bank',
    'First Abu Dhabi Bank',
    'RAKBANK',
  ];

  final DatabaseService _dbService = DatabaseService();
  final List<TransactionItem> _transactions = [];

  @override
  void initState() {
    super.initState();
    _checkSavedWallet();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _transactionSub?.cancel();
    _fullNameController.dispose();
    _ibanController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<String> _getUserKey() async {
    final authUser = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    return authUser?.uid ?? prefs.getString('phoneNumber') ?? prefs.getString('email') ?? '';
  }

  void _updateBalanceFromData(Map<String, dynamic> data) {
    final balanceDetails = data['balanceDetails'] as Map<String, dynamic>?;

    final current = (data['walletBalance'] as num?)?.toDouble() ??
        (data['balance'] as num?)?.toDouble() ??
        (balanceDetails?['currentBalance'] as num?)?.toDouble() ??
        (balanceDetails?['walletBalance'] as num?)?.toDouble() ??
        0.0;

    final pending = (data['pendingBalance'] as num?)?.toDouble() ??
        (balanceDetails?['pendingEscrow'] as num?)?.toDouble() ??
        (balanceDetails?['pendingBalance'] as num?)?.toDouble() ??
        0.0;

    if (mounted) {
      setState(() {
        _availableBalance = current;
        _pendingBalance = pending;
        _totalBalance = current + pending;
      });
    }
  }

  void _updateBankDetailsFromData(Map<String, dynamic> data) {
    final bankMap = (data['bankDetails'] as Map<String, dynamic>?) ?? data;
    final bankName = bankMap['bankName'] as String? ?? data['bankName'] as String?;
    final fullName = bankMap['fullName'] as String? ?? data['fullName'] as String?;
    final iban = bankMap['iban'] as String? ?? data['iban'] as String?;
    final accNum = bankMap['accountNumber'] as String? ?? data['accountNumber'] as String?;

    if ((bankName != null && bankName.isNotEmpty) ||
        (fullName != null && fullName.isNotEmpty) ||
        (iban != null && iban.isNotEmpty) ||
        (accNum != null && accNum.isNotEmpty)) {
      if (mounted) {
        setState(() {
          _hasSavedWallet = true;
          if (bankName != null && bankName.isNotEmpty) _selectedBank = bankName;
          if (fullName != null && fullName.isNotEmpty) _fullNameController.text = fullName;
          if (iban != null && iban.isNotEmpty) _ibanController.text = iban;
          if (accNum != null && accNum.isNotEmpty) _accountNumberController.text = accNum;
        });
      }
    }
  }

  Future<void> _checkSavedWallet() async {
    final userKey = await _getUserKey();
    final prefs = await SharedPreferences.getInstance();

    if (userKey.isNotEmpty) {
      final techDoc = await _dbService.getTechProfile(userKey);
      final techId = techDoc.exists ? techDoc.id : userKey;
      _canonicalTechId = techId;

      if (techDoc.exists && techDoc.data() != null) {
        final data = techDoc.data()!;
        _updateBalanceFromData(data);
        _updateBankDetailsFromData(data);
      }

      // 1. Listen to Tech Profile Stream for real-time balance updates
      _profileSub?.cancel();
      _profileSub = _dbService.streamTechProfile(techId).listen((snap) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          _updateBalanceFromData(data);
          _updateBankDetailsFromData(data);
        }
      });

      // 2. Listen to Tech Transactions Stream
      _transactionSub?.cancel();
      _transactionSub = PaymentAndTransactionService().fetchUserTransactions(techId, isTech: true).listen((txList) {
        final loaded = txList.map((tx) {
          final isCredit = tx.netTechnicianEarnings >= 0;
          final sign = isCredit ? '+' : '';
          final amountStr = '$sign${tx.netTechnicianEarnings.toStringAsFixed(0)} AED';

          String dateGroup = 'Recent';
          if (tx.timestamp != null) {
            final now = DateTime.now();
            final txDate = tx.timestamp!;
            final diffDays = now.difference(txDate).inDays;
            if (txDate.year == now.year && txDate.month == now.month && txDate.day == now.day) {
              dateGroup = 'Today';
            } else if (diffDays == 1 || (diffDays == 0 && txDate.day != now.day)) {
              dateGroup = 'Yesterday';
            } else {
              dateGroup = 'Earlier';
            }
          }

          final isWithdrawal = tx.bookingId == 'WITHDRAWAL';
          return TransactionItem(
            title: isWithdrawal ? 'Withdrawal' : 'Job Earnings',
            subtitle: isWithdrawal ? 'Bank Transfer' : 'Booking #${tx.bookingId}',
            amount: amountStr,
            isCredit: isCredit,
            dateGroup: dateGroup,
          );
        }).toList();

        if (mounted) {
          setState(() {
            _transactions.clear();
            _transactions.addAll(loaded);
          });
        }
      });

      try {
        final doc = await _dbService.getTechBankDetails(techId);
        if (doc.exists && doc.data() != null) {
          _updateBankDetailsFromData(doc.data()!);
        }
      } catch (_) {}
    }

    final bool hasWallet = prefs.getBool('has_saved_wallet') ?? false;
    if (!mounted) return;
    setState(() {
      if (!_hasSavedWallet) {
        _hasSavedWallet = hasWallet;
        if (hasWallet) {
          _selectedBank = prefs.getString('wallet_bank_name') ?? 'ADCB';
          _fullNameController.text = prefs.getString('wallet_full_name') ?? '';
          _ibanController.text = prefs.getString('wallet_iban') ?? '';
          _accountNumberController.text = prefs.getString('wallet_account_number') ?? '';
        }
      }
      _isLoading = false;
    });
  }

  Future<void> _saveWalletDetails() async {
    if (_fullNameController.text.trim().isEmpty ||
        _ibanController.text.trim().isEmpty ||
        _accountNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all bank details')),
      );
      return;
    }

    final userKey = _canonicalTechId.isNotEmpty ? _canonicalTechId : await _getUserKey();
    final bankData = {
      'bankName': _selectedBank,
      'fullName': _fullNameController.text.trim(),
      'iban': _ibanController.text.trim(),
      'accountNumber': _accountNumberController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (userKey.isNotEmpty) {
      final techDoc = await _dbService.getTechProfile(userKey);
      final techId = techDoc.exists ? techDoc.id : userKey;
      await _dbService.saveTechBankDetails(techId, bankData);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_saved_wallet', true);
    await prefs.setString('wallet_bank_name', _selectedBank);
    await prefs.setString('wallet_full_name', _fullNameController.text.trim());
    await prefs.setString('wallet_iban', _ibanController.text.trim());
    await prefs.setString('wallet_account_number', _accountNumberController.text.trim());

    if (!mounted) return;
    setState(() {
      _hasSavedWallet = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bank account added successfully!')),
    );
  }

  void _showWithdrawDialog() {
    final TextEditingController amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Withdraw Funds',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Available Balance: ${_availableBalance.toStringAsFixed(2)} AED',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'Enter Amount (AED)',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final amountText = amountController.text.trim();
                    final enteredAmount = double.tryParse(amountText);

                    if (enteredAmount == null || enteredAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid withdrawal amount')),
                      );
                      return;
                    }

                    if (enteredAmount > _availableBalance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Withdrawal amount exceeds available balance')),
                      );
                      return;
                    }

                    final userKey = _canonicalTechId.isNotEmpty ? _canonicalTechId : await _getUserKey();
                    if (userKey.isNotEmpty) {
                      final techDoc = await _dbService.getTechProfile(userKey);
                      final techId = techDoc.exists ? techDoc.id : userKey;
                      await _dbService.withdrawTechBalance(techId, enteredAmount, {
                        'bankName': _selectedBank,
                        'fullName': _fullNameController.text.trim(),
                        'iban': _ibanController.text.trim(),
                        'accountNumber': _accountNumberController.text.trim(),
                      });
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Withdrawal request of ${enteredAmount.toStringAsFixed(2)} AED submitted!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Confirm Withdrawal', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
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
                  const SizedBox(width: 16),
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

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: _hasSavedWallet
                          ? _buildSavedWalletContent()
                          : _buildAddBankAccountContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STATE 1: ADD BANK ACCOUNT FORM (EMPTY PLACEHOLDERS)
  // ==========================================
  Widget _buildAddBankAccountContent() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text(
                'Add Bank Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 20),

              // Bank Name Dropdown
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBank,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedBank = val);
                      }
                    },
                    items: _bankOptions.map((bank) {
                      return DropdownMenuItem<String>(
                        value: bank,
                        child: Text(bank),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Full Name Text Field
              _buildFormTextField(
                controller: _fullNameController,
                hintText: 'Full Name',
              ),

              const SizedBox(height: 14),

              // IBAN Text Field
              _buildFormTextField(
                controller: _ibanController,
                hintText: 'IBAN',
              ),

              const SizedBox(height: 14),

              // Account Number Text Field
              _buildFormTextField(
                controller: _accountNumberController,
                hintText: 'Account Number',
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 22),

              // Add Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveWalletDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w500),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ==========================================
  // STATE 2: SAVED WALLET & TRANSACTIONS
  // ==========================================
  Widget _buildSavedWalletContent() {
    final todayTransactions = _transactions.where((t) => t.dateGroup == 'Today').toList();
    final yesterdayTransactions = _transactions.where((t) => t.dateGroup == 'Yesterday').toList();
    final earlierTransactions = _transactions.where((t) => t.dateGroup != 'Today' && t.dateGroup != 'Yesterday').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bank Account Details Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Bank Logo Badge Container
              _buildBankLogoBadge(_selectedBank),

              const SizedBox(width: 12),

              // Bank Name, Holder Name, IBAN, Account Number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedBank,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fullNameController.text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _ibanController.text,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _accountNumberController.text,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              // Edit Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _hasSavedWallet = false;
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mode_edit_outlined, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Total, Pending, Available Balance Banner
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _buildBalanceColumn('Total', _totalBalance),
              Container(width: 1, height: 48, color: const Color(0xFF333333)),
              _buildBalanceColumn('Pending', _pendingBalance),
              Container(width: 1, height: 48, color: const Color(0xFF333333)),
              _buildBalanceColumn('Available', _availableBalance),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Terms / Rules Bullet Points
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '- Withdrawals will be made Twice a week on Monday and Thursday',
                style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.35),
              ),
              Text(
                '- Total Balance : Net Balance after deducting our fees 10% from each order.',
                style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.35),
              ),
              Text(
                '- Note: Amount is being held for 7 days to make sure everything works smooth for both tech and user.',
                style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.35),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Action Buttons Bar (Withdraw & History)
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showWithdrawDialog,
                  behavior: HitTestBehavior.opaque,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.remove_circle_outline, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Withdraw',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white24),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Showing transaction history')),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
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

        const SizedBox(height: 24),

        // Transactions Header
        const Text(
          'Transactions',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 12),

        if (_transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ),
          ),

        // Today Group
        if (todayTransactions.isNotEmpty) ...[
          const Text(
            'Today',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          ...todayTransactions.map((t) => _buildTransactionTile(t)),
          const SizedBox(height: 16),
        ],

        // Yesterday Group
        if (yesterdayTransactions.isNotEmpty) ...[
          const Text(
            'Yesterday',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          ...yesterdayTransactions.map((t) => _buildTransactionTile(t)),
          const SizedBox(height: 16),
        ],

        // Earlier Group
        if (earlierTransactions.isNotEmpty) ...[
          const Text(
            'Recent',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          ...earlierTransactions.map((t) => _buildTransactionTile(t)),
        ],
      ],
    );
  }

  // Dynamic Bank Logo Badge Helper
  Widget _buildBankLogoBadge(String bankName) {
    switch (bankName) {
      case 'Emirates NBD':
        return Container(
          width: 86,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF002B49),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(6),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'NBD',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                'Emirates NBD',
                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ],
          ),
        );
      case 'Dubai Islamic Bank':
        return Container(
          width: 86,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF006039),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(6),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Color(0xFFFFC107), size: 13),
                  SizedBox(width: 2),
                  Text(
                    'DIB',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                'دبي الإسلامي',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ],
          ),
        );
      case 'Mashreq Bank':
        return Container(
          width: 86,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFE65100),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(6),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 16),
              SizedBox(height: 2),
              Text(
                'Mashreq',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        );
      case 'First Abu Dhabi Bank':
        return Container(
          width: 86,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFC8102E),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(6),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'FAB',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
              ),
              SizedBox(height: 1),
              Text(
                'أبوظبي الأول',
                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ],
          ),
        );
      case 'RAKBANK':
        return Container(
          width: 86,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFB71C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(6),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, color: Colors.white, size: 15),
              SizedBox(height: 2),
              Text(
                'RAKBANK',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        );
      case 'ADCB':
      default:
        return Container(
          width: 86,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ADCB',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 2),
                  CustomPaint(
                    size: const Size(12, 12),
                    painter: _RedTrianglePainter(),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'بنك أبوظبي التجاري',
                style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildBalanceColumn(String label, double value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'AED',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(TransactionItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Icon Circle
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
          // Title & Subtitle
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
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Amount
          Text(
            item.amount,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: item.isCredit ? Colors.black : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// ADCB Logo Red Triangle Painter
class _RedTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
