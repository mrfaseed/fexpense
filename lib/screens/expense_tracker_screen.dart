import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account_vault.dart';
import '../services/app_reset_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'google_auth_screen.dart';

class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final IconData icon;
  final DateTime date;
  final String? accountId;
  final String? accountName;

  ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.icon,
    required this.date,
    this.accountId,
    this.accountName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'iconCode': icon.codePoint,
        'date': date.toIso8601String(),
        'accountId': accountId,
        'accountName': accountName,
      };

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        icon: iconFromCategory(json['category'] as String),
        date: DateTime.parse(json['date'] as String),
        accountId: json['accountId'] as String?,
        accountName: json['accountName'] as String?,
      );

  static IconData iconFromCategory(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Transport':
        return Icons.directions_car_outlined;
      case 'Bills':
        return Icons.receipt_long_outlined;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Health':
        return Icons.medical_services_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String _userName = 'Mohamed';
  String? _userPhotoUrl;
  String _currencySymbol = '₹';
  String _walletType = 'All In One';
  double _totalBudget = 7000.0;
  List<ExpenseItem> _expenses = [];
  List<AccountVault> _accounts = [];

  bool _isLoading = true;
  StreamSubscription<List<ExpenseItem>>? _expenseSub;
  StreamSubscription<List<AccountVault>>? _accountsSub;

  int _selectedNavIndex = 0; // 0: Home, 1: Analytics, 2: Categories, 3: Budgets, 4: Settings
  String _selectedCategoryFilter = 'All';
  String? _selectedAccountId; // null means "All Vaults"

  // Mint & Forest Theme Palette
  static const Color bgDark = Color(0xFF070C0E);
  static const Color sidebarBg = Color(0xFF060A0C);
  static const Color sidebarBorder = Color(0xFF10191D);
  static const Color cardBg = Color(0xFF0C1417);
  static const Color cardBorder = Color(0xFF152227);
  static const Color heroBgStart = Color(0xFF091C19);
  static const Color heroBgEnd = Color(0xFF081715);
  static const Color heroBorder = Color(0xFF13453D);
  static const Color mint = Color(0xFF00D09C);
  static const Color rose = Color(0xFFF43F5E);
  static const Color indigo = Color(0xFF6366F1);
  static const Color amber = Color(0xFFF59E0B);
  static const Color textSecondary = Color(0xFF8B9CA3);
  static const Color textTertiary = Color(0xFF55656C);

  @override
  void initState() {
    super.initState();
    _initDataAndStreams();
  }

  @override
  void dispose() {
    _expenseSub?.cancel();
    _accountsSub?.cancel();
    super.dispose();
  }

  Future<void> _initDataAndStreams() async {
    final uid = _authService.currentUid;
    final prefs = await SharedPreferences.getInstance();

    _userName = prefs.getString('user_name') ??
        (_authService.currentDisplayName.isNotEmpty
            ? _authService.currentDisplayName
            : 'Mohamed');
    _currencySymbol = prefs.getString('currency_symbol') ?? '₹';
    _walletType = prefs.getString('wallet_type') ?? 'All In One';
    _totalBudget = prefs.getDouble('total_budget') ?? 7000.0;
    _userPhotoUrl = _authService.currentPhotoUrl;

    // 1. Load local cached accounts
    final accountsCache = prefs.getStringList('accounts_cache') ?? [];
    if (accountsCache.isNotEmpty) {
      _accounts = accountsCache
          .map((item) =>
              AccountVault.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    }

    // 2. Load local cached expenses
    final expenseListJson = prefs.getStringList('expenses_history') ?? [];
    if (expenseListJson.isNotEmpty) {
      _expenses = expenseListJson
          .map((item) =>
              ExpenseItem.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    }

    try {
      final profile = await _firestoreService.getUserProfile(uid);
      if (profile != null) {
        _userName = profile['name'] as String? ?? _userName;
        _currencySymbol =
            profile['currencySymbol'] as String? ?? _currencySymbol;
        _walletType = profile['walletType'] as String? ?? _walletType;
        _totalBudget =
            (profile['totalBudget'] as num?)?.toDouble() ?? _totalBudget;
      }

      // 3. Listen to real-time Cloud Firestore updates for accounts
      _accountsSub = _firestoreService.streamAccounts(uid).listen(
        (remoteAccounts) {
          if (mounted) {
            if (remoteAccounts.isEmpty) {
              // Auto-migrate single budget into multi-account vault system
              _autoMigrateInitialAccounts(uid, _totalBudget);
            } else {
              setState(() {
                _accounts = remoteAccounts;
              });
              _persistLocalAccounts();
            }
          }
        },
        onError: (err) {
          debugPrint('Firestore accounts stream error: $err');
          if (_accounts.isEmpty) {
            _autoMigrateInitialAccounts(uid, _totalBudget);
          }
        },
      );

      // 4. Listen to real-time Cloud Firestore updates for expenses
      _expenseSub = _firestoreService.streamExpenses(uid).listen(
        (remoteExpenses) {
          if (mounted) {
            setState(() {
              _expenses = remoteExpenses;
            });
            _persistLocalExpenses();
          }
        },
        onError: (err) {
          debugPrint('Firestore stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Firestore init error: $e');
      if (_accounts.isEmpty) {
        _autoMigrateInitialAccounts(uid, _totalBudget);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _autoMigrateInitialAccounts(
      String uid, double existingBudget) async {
    final bankBalance = existingBudget > 0 ? existingBudget : 7000.0;
    const cashBalance = 400.0; // Default cash in hand demonstration balance

    final defaultBank = AccountVault(
      id: 'acc_bank_default',
      name: 'Primary Bank',
      type: 'bank',
      balance: bankBalance,
      iconCode: Icons.account_balance_rounded.codePoint,
      colorValue: 0xFF818CF8,
      createdAt: DateTime.now(),
      isPrimary: true,
    );

    final defaultCash = AccountVault(
      id: 'acc_cash_default',
      name: 'Cash in Hand',
      type: 'cash',
      balance: cashBalance,
      iconCode: Icons.payments_rounded.codePoint,
      colorValue: 0xFF34D399,
      createdAt: DateTime.now().add(const Duration(seconds: 1)),
      isPrimary: false,
    );

    final list = [defaultBank, defaultCash];
    setState(() {
      _accounts = list;
    });
    _persistLocalAccounts();

    try {
      await _firestoreService.saveAccount(uid, defaultBank);
      await _firestoreService.saveAccount(uid, defaultCash);
    } catch (e) {
      debugPrint('Auto-migration save error: $e');
    }
  }

  Future<void> _persistLocalAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList =
        _accounts.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('accounts_cache', jsonList);
  }

  Future<void> _persistLocalExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList =
        _expenses.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('expenses_history', jsonList);
  }

  // --- Dynamic Mathematical Calculations ---

  AccountVault? get _primaryAccount {
    final matches = _accounts.where((a) => a.isPrimary);
    if (matches.isNotEmpty) return matches.first;
    return _accounts.isNotEmpty ? _accounts.first : null;
  }

  double get _totalConsolidatedBalance =>
      _accounts.fold(0.0, (sum, acc) => sum + acc.balance);

  double get _activeRemainingBalance {
    if (_selectedAccountId == null) {
      return _totalConsolidatedBalance;
    }
    final match = _accounts.where((a) => a.id == _selectedAccountId);
    return match.isNotEmpty ? match.first.balance : 0.0;
  }

  double get _activeSpentTotal {
    if (_selectedAccountId == null) {
      return _expenses.fold(0.0, (sum, item) => sum + item.amount);
    }
    return _expenses
        .where((e) => e.accountId == _selectedAccountId)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _activeStartingMoney =>
      _activeRemainingBalance + _activeSpentTotal;

  double get _remainingRatio => _activeStartingMoney <= 0
      ? 0
      : (_activeRemainingBalance / _activeStartingMoney).clamp(0.0, 1.0);

  List<ExpenseItem> get _filteredExpenses {
    var list = _expenses;
    if (_selectedAccountId != null) {
      list = list.where((e) => e.accountId == _selectedAccountId).toList();
    }
    if (_selectedCategoryFilter != 'All') {
      list = list.where((e) => e.category == _selectedCategoryFilter).toList();
    }
    return list;
  }

  int get _categoriesCount {
    final cats = _filteredExpenses.map((e) => e.category).toSet();
    return cats.isEmpty ? 0 : cats.length;
  }

  // --- Actions ---

  void _addExpense({
    required String title,
    required double amount,
    required String category,
    required IconData icon,
    required String accountId,
    required String accountName,
  }) async {
    final item = ExpenseItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Spend' : title.trim(),
      amount: amount,
      category: category,
      icon: icon,
      date: DateTime.now(),
      accountId: accountId,
      accountName: accountName,
    );

    // 1. Decrement balance from specific account
    final accIndex = _accounts.indexWhere((a) => a.id == accountId);
    if (accIndex != -1) {
      final acc = _accounts[accIndex];
      final newBal = (acc.balance - amount).clamp(-99999999.0, 99999999.0);
      final updatedAcc = acc.copyWith(balance: newBal);
      setState(() {
        _accounts[accIndex] = updatedAcc;
        _expenses.insert(0, item);
      });
      _persistLocalAccounts();
      _persistLocalExpenses();

      final uid = _authService.currentUid;
      await _firestoreService.updateAccountBalance(uid, accountId, newBal);
      await _firestoreService.addExpense(uid, item);
    } else {
      setState(() {
        _expenses.insert(0, item);
      });
      _persistLocalExpenses();
      final uid = _authService.currentUid;
      await _firestoreService.addExpense(uid, item);
    }
  }

  void _deleteExpense(String id) async {
    final item = _expenses.firstWhere((e) => e.id == id);

    // Refund amount back to account if known
    if (item.accountId != null) {
      final accIndex = _accounts.indexWhere((a) => a.id == item.accountId);
      if (accIndex != -1) {
        final acc = _accounts[accIndex];
        final newBal = acc.balance + item.amount;
        setState(() {
          _accounts[accIndex] = acc.copyWith(balance: newBal);
          _expenses.removeWhere((e) => e.id == id);
        });
        _persistLocalAccounts();
        _persistLocalExpenses();

        final uid = _authService.currentUid;
        await _firestoreService.updateAccountBalance(
            uid, item.accountId!, newBal);
        await _firestoreService.deleteExpense(uid, id);
        return;
      }
    }

    setState(() {
      _expenses.removeWhere((e) => e.id == id);
    });
    _persistLocalExpenses();

    final uid = _authService.currentUid;
    await _firestoreService.deleteExpense(uid, id);
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder),
        ),
        title: const Text(
          'Log Out of Google?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You will be signed out from ${_authService.currentEmail}. Your multi-account vaults and expenses are securely backed up in Firebase.',
          style: const TextStyle(
            color: textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(90, 40),
              backgroundColor: rose,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _authService.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 500),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const GoogleAuthScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // "ADD MONEY / TOTAL" SUPER-MODAL (Deposit, New Vault, Transfer)
  // ---------------------------------------------------------
  void _openAddMoneySuperModal(
      {int initialTab = 0, String? preselectedAccountId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: cardBorder),
      ),
      builder: (ctx) {
        int currentTab = initialTab; // 0: Deposit, 1: New Vault, 2: Transfer

        // Deposit State
        String selectedDepositAccId = preselectedAccountId ??
            (_selectedAccountId ??
                (_primaryAccount?.id ??
                    (_accounts.isNotEmpty ? _accounts.first.id : '')));
        final depositController = TextEditingController();

        // New Vault State
        final newVaultNameController = TextEditingController();
        final newVaultBalController = TextEditingController();
        String selectedVaultType = 'bank';

        // Transfer State
        String sourceAccId =
            _accounts.isNotEmpty ? _accounts.first.id : '';
        String destAccId =
            _accounts.length > 1 ? _accounts[1].id : (_accounts.isNotEmpty ? _accounts.first.id : '');
        final transferAmountController = TextEditingController();

        String? modalError;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Liquidity Vault Engine',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: textSecondary, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3-Segment Tab Switcher (Deposit | New Vault | Transfer)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      children: [
                        _buildModalTab(
                          label: 'Deposit',
                          icon: Icons.add_circle_outline_rounded,
                          isSelected: currentTab == 0,
                          onTap: () => setModalState(() {
                            currentTab = 0;
                            modalError = null;
                          }),
                        ),
                        _buildModalTab(
                          label: 'New Vault',
                          icon: Icons.account_balance_outlined,
                          isSelected: currentTab == 1,
                          onTap: () => setModalState(() {
                            currentTab = 1;
                            modalError = null;
                          }),
                        ),
                        _buildModalTab(
                          label: 'Transfer',
                          icon: Icons.swap_horiz_rounded,
                          isSelected: currentTab == 2,
                          onTap: () => setModalState(() {
                            currentTab = 2;
                            modalError = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Tab 0: DEPOSIT / TOP-UP
                  if (currentTab == 0) ...[
                    const Text(
                      'DEPOSIT TARGET VAULT',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _accounts.map((acc) {
                        final isSelected = selectedDepositAccId == acc.id;
                        return ChoiceChip(
                          selected: isSelected,
                          avatar: Icon(acc.icon,
                              size: 15,
                              color: isSelected ? Colors.black : acc.color),
                          label: Text(
                            '${acc.name} ($_currencySymbol${acc.balance.toStringAsFixed(0)})',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          selectedColor: mint,
                          backgroundColor: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: isSelected ? mint : cardBorder),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(
                                  () => selectedDepositAccId = acc.id);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'AMOUNT TO ADD',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: depositController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      autofocus: true,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        prefixText: '+$_currencySymbol ',
                        prefixStyle: const TextStyle(
                            color: mint,
                            fontSize: 22,
                            fontWeight: FontWeight.w700),
                        hintText: '1000',
                        hintStyle: const TextStyle(color: textTertiary),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: mint),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Quick Boost Chips
                    Wrap(
                      spacing: 8,
                      children: [500.0, 1000.0, 5000.0, 10000.0].map((val) {
                        return InkWell(
                          onTap: () {
                            final curr =
                                double.tryParse(depositController.text) ?? 0.0;
                            depositController.text =
                                (curr + val).toInt().toString();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Text(
                              '+$_currencySymbol${val.toInt()}',
                              style: const TextStyle(
                                  color: textSecondary, fontSize: 11),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mint,
                          foregroundColor: const Color(0xFF061F1A),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final amount =
                              double.tryParse(depositController.text.trim());
                          if (amount == null || amount <= 0) {
                            setModalState(() => modalError =
                                'Please enter a valid deposit amount.');
                            return;
                          }
                          final targetIndex = _accounts
                              .indexWhere((a) => a.id == selectedDepositAccId);
                          if (targetIndex != -1) {
                            final target = _accounts[targetIndex];
                            final newBal = target.balance + amount;
                            setState(() {
                              _accounts[targetIndex] =
                                  target.copyWith(balance: newBal);
                            });
                            _persistLocalAccounts();
                            final uid = _authService.currentUid;
                            await _firestoreService.updateAccountBalance(
                                uid, target.id, newBal);
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                          }
                        },
                        child: const Text('Add Funds to Vault ⚡',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],

                  // Tab 1: NEW VAULT / BANK ACCOUNT
                  if (currentTab == 1) ...[
                    const Text(
                      'VAULT NAME',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newVaultNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. HDFC Bank, Cash in Hand, SBI, Savings...',
                        hintStyle: const TextStyle(color: textTertiary),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: mint),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'VAULT TYPE',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['bank', 'cash', 'savings', 'wallet'].map((t) {
                        final isSelected = selectedVaultType == t;
                        final icon = AccountVault.defaultIconForType(t);
                        final label = t == 'bank'
                            ? 'Bank Account'
                            : (t == 'cash'
                                ? 'Cash in Hand'
                                : (t == 'savings' ? 'Savings' : 'Wallet'));
                        return ChoiceChip(
                          selected: isSelected,
                          avatar: Icon(icon,
                              size: 15,
                              color: isSelected ? Colors.black : Colors.white),
                          label: Text(
                            label,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          selectedColor: mint,
                          backgroundColor: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: isSelected ? mint : cardBorder),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => selectedVaultType = t);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'STARTING BALANCE',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newVaultBalController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        prefixText: '$_currencySymbol ',
                        prefixStyle: const TextStyle(
                            color: mint,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                        hintText: '0.00',
                        hintStyle: const TextStyle(color: textTertiary),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: mint),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mint,
                          foregroundColor: const Color(0xFF061F1A),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final name = newVaultNameController.text.trim();
                          final balance =
                              double.tryParse(newVaultBalController.text.trim()) ??
                                  0.0;
                          if (name.isEmpty) {
                            setModalState(() =>
                                modalError = 'Please enter a vault name.');
                            return;
                          }
                          final newAcc = AccountVault(
                            id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            type: selectedVaultType,
                            balance: balance,
                            iconCode: AccountVault.defaultIconForType(
                                    selectedVaultType)
                                .codePoint,
                            colorValue: AccountVault.defaultColorForType(
                                    selectedVaultType)
                                .toARGB32(),
                            createdAt: DateTime.now(),
                          );
                          setState(() {
                            _accounts.add(newAcc);
                          });
                          _persistLocalAccounts();
                          final uid = _authService.currentUid;
                          await _firestoreService.saveAccount(uid, newAcc);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                        child: const Text('Create New Vault 🏦',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],

                  // Tab 2: INTERNAL TRANSFER (Bank -> Cash)
                  if (currentTab == 2) ...[
                    const Text(
                      'TRANSFER FROM',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: sourceAccId,
                      dropdownColor: cardBg,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                      ),
                      items: _accounts.map((acc) {
                        return DropdownMenuItem(
                          value: acc.id,
                          child: Text(
                              '${acc.name} ($_currencySymbol${acc.balance.toStringAsFixed(0)} available)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => sourceAccId = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'TRANSFER TO (DESTINATION)',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: destAccId,
                      dropdownColor: cardBg,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                      ),
                      items: _accounts.map((acc) {
                        return DropdownMenuItem(
                          value: acc.id,
                          child: Text(
                              '${acc.name} ($_currencySymbol${acc.balance.toStringAsFixed(0)})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => destAccId = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'TRANSFER AMOUNT',
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: transferAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        prefixText: '$_currencySymbol ',
                        prefixStyle: const TextStyle(
                            color: mint,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                        hintText: '500',
                        hintStyle: const TextStyle(color: textTertiary),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: mint),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mint,
                          foregroundColor: const Color(0xFF061F1A),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (sourceAccId == destAccId) {
                            setModalState(() => modalError =
                                'Source and Destination cannot be the same vault.');
                            return;
                          }
                          final amount = double.tryParse(
                              transferAmountController.text.trim());
                          if (amount == null || amount <= 0) {
                            setModalState(() => modalError =
                                'Please enter a valid transfer amount.');
                            return;
                          }
                          final sIndex = _accounts
                              .indexWhere((a) => a.id == sourceAccId);
                          final dIndex =
                              _accounts.indexWhere((a) => a.id == destAccId);
                          if (sIndex != -1 && dIndex != -1) {
                            final sourceAcc = _accounts[sIndex];
                            final destAcc = _accounts[dIndex];
                            if (sourceAcc.balance < amount) {
                              setModalState(() => modalError =
                                  'Insufficient balance in ${sourceAcc.name}.');
                              return;
                            }
                            final newSourceBal = sourceAcc.balance - amount;
                            final newDestBal = destAcc.balance + amount;

                            setState(() {
                              _accounts[sIndex] =
                                  sourceAcc.copyWith(balance: newSourceBal);
                              _accounts[dIndex] =
                                  destAcc.copyWith(balance: newDestBal);
                            });
                            _persistLocalAccounts();

                            final uid = _authService.currentUid;
                            await _firestoreService.updateAccountBalance(
                                uid, sourceAcc.id, newSourceBal);
                            await _firestoreService.updateAccountBalance(
                                uid, destAcc.id, newDestBal);
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                          }
                        },
                        child: const Text('Execute Internal Transfer ⇄',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],

                  if (modalError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      modalError!,
                      style: const TextStyle(color: rose, fontSize: 12),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? mint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isSelected ? const Color(0xFF061F1A) : textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF061F1A) : textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // RECORD SPEND (With Paid-From Account Selector)
  // ---------------------------------------------------------
  void _openAddSpendBottomSheet() {
    final amountController = TextEditingController();
    final titleController = TextEditingController();
    String selectedCategory = 'Food';
    IconData selectedIcon = Icons.restaurant_outlined;

    String selectedSpendAccountId = _selectedAccountId ??
        (_primaryAccount?.id ??
            (_accounts.isNotEmpty ? _accounts.first.id : ''));

    final categories = [
      {'name': 'Food', 'icon': Icons.restaurant_outlined},
      {'name': 'Transport', 'icon': Icons.directions_car_outlined},
      {'name': 'Bills', 'icon': Icons.receipt_long_outlined},
      {'name': 'Shopping', 'icon': Icons.shopping_bag_outlined},
      {'name': 'Health', 'icon': Icons.medical_services_outlined},
      {'name': 'Other', 'icon': Icons.category_outlined},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: cardBorder),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final activeAccount = _accounts.firstWhere(
              (a) => a.id == selectedSpendAccountId,
              orElse: () => _accounts.first,
            );

            final enteredAmount =
                double.tryParse(amountController.text.trim()) ?? 0.0;
            final isExceeding = enteredAmount > activeAccount.balance;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Record Spend',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: textSecondary, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select which vault or hand cash you paid from. Balances will decrement in real time.',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Paid From Vault Selector
                  const Text(
                    'PAID FROM (VAULT / CASH)',
                    style: TextStyle(
                      color: textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _accounts.map((acc) {
                      final isSelected = selectedSpendAccountId == acc.id;
                      return ChoiceChip(
                        selected: isSelected,
                        avatar: Icon(acc.icon,
                            size: 15,
                            color: isSelected ? Colors.black : acc.color),
                        label: Text(
                          '${acc.name} ($_currencySymbol${acc.balance.toStringAsFixed(0)})',
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        selectedColor: mint,
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? mint : cardBorder,
                            width: 1,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              selectedSpendAccountId = acc.id;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Amount Spent Input
                  const Text(
                    'AMOUNT SPENT',
                    style: TextStyle(
                      color: textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    onChanged: (_) => setModalState(() {}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      prefixText: '$_currencySymbol ',
                      prefixStyle: const TextStyle(
                        color: mint,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: '0.00',
                      hintStyle: const TextStyle(color: textTertiary),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: mint),
                      ),
                    ),
                  ),
                  if (isExceeding) ...[
                    const SizedBox(height: 6),
                    Text(
                      '⚠️ Warning: Exceeds ${activeAccount.name} balance ($_currencySymbol${activeAccount.balance.toStringAsFixed(0)})',
                      style: const TextStyle(color: rose, fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Spend Details / Note
                  const Text(
                    'SPEND DETAILS / NOTE',
                    style: TextStyle(
                      color: textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Lunch, Coffee, Groceries, Petrol...',
                      hintStyle: const TextStyle(color: textTertiary),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: mint),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  const Text(
                    'CATEGORY',
                    style: TextStyle(
                      color: textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat['name'];
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          cat['name'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.black : textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        avatar: Icon(
                          cat['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.black : textSecondary,
                        ),
                        selectedColor: mint,
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? mint : cardBorder,
                            width: 1,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              selectedCategory = cat['name'] as String;
                              selectedIcon = cat['icon'] as IconData;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mint,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final amount = double.tryParse(amountController.text);
                        if (amount != null && amount > 0) {
                          _addExpense(
                            title: titleController.text,
                            amount: amount,
                            category: selectedCategory,
                            icon: selectedIcon,
                            accountId: activeAccount.id,
                            accountName: activeAccount.name,
                          );
                          Navigator.of(ctx).pop();
                        }
                      },
                      child: Text('Deduct From ${activeAccount.name}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openQuickSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: cardBorder),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: heroBorder,
                    backgroundImage: _userPhotoUrl != null
                        ? NetworkImage(_userPhotoUrl!)
                        : null,
                    child: _userPhotoUrl == null
                        ? const Icon(Icons.person, color: mint)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _authService.currentEmail.isNotEmpty
                              ? _authService.currentEmail
                              : 'Google Account',
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined,
                      color: mint, size: 20),
                ),
                title: const Text('Manage Liquidity Vaults',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, color: textSecondary),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openAddMoneySuperModal(initialTab: 1);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: rose.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_sweep_outlined,
                      color: rose, size: 20),
                ),
                title: const Text('Factory Reset App (Clear All)',
                    style: TextStyle(color: rose, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, color: textSecondary),
                onTap: () {
                  Navigator.of(ctx).pop();
                  AppResetService.confirmAndReset(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_outlined,
                      color: Colors.white, size: 20),
                ),
                title: const Text('Log Out',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, color: textSecondary),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bgDark,
        body: Center(
          child: CircularProgressIndicator(color: mint),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 820;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: bgDark,
      drawer: !isDesktop
          ? Drawer(
              backgroundColor: sidebarBg,
              child: SafeArea(
                child: _buildSidebarContent(isDrawer: true),
              ),
            )
          : null,
      bottomNavigationBar: !isDesktop ? _buildMobileBottomBar() : null,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Navigation Sidebar (desktop only)
            if (isDesktop) _buildSidebar(),

            // Main Dashboard Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 14 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header Bar
                    _buildTopHeader(isMobile),
                    SizedBox(height: isMobile ? 16 : 20),

                    // Main Hero Balance Card
                    _buildHeroCard(isMobile),
                    SizedBox(height: isMobile ? 16 : 20),

                    // Dedicated "My Accounts & Cash" Horizontal Section
                    _buildAccountsSection(isMobile),
                    SizedBox(height: isMobile ? 18 : 22),

                    // 4 Quick Metric Cards
                    _buildMetricCardsRow(isMobile),
                    SizedBox(height: isMobile ? 16 : 20),

                    // Full-Width Action Button: + Add Spend / Expense
                    _buildAddSpendButton(),
                    SizedBox(height: isMobile ? 20 : 24),

                    // Recent Spends Section
                    _buildRecentSpendsSection(isMobile),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 1. LEFT SIDEBAR NAVIGATION
  // ---------------------------------------------------------
  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(color: sidebarBorder, width: 1.2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: _buildSidebarContent(isDrawer: false),
    );
  }

  Widget _buildSidebarContent({required bool isDrawer}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo & Brand Header
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FExpense',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Track. Plan. Grow.',
                  style: TextStyle(
                    color: textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Menu Navigation Items
        _buildSidebarItem(
          index: 0,
          icon: Icons.home_rounded,
          title: 'Home',
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 8),
        _buildSidebarItem(
          index: 1,
          icon: Icons.bar_chart_rounded,
          title: 'Analytics',
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 8),
        _buildSidebarItem(
          index: 2,
          icon: Icons.grid_view_rounded,
          title: 'Categories',
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 8),
        _buildSidebarItem(
          index: 3,
          icon: Icons.account_balance_wallet_outlined,
          title: 'Budgets',
          isDrawer: isDrawer,
          onTap: () {
            if (isDrawer) Navigator.of(context).pop();
            _openAddMoneySuperModal(initialTab: 0);
          },
        ),
        const SizedBox(height: 8),
        _buildSidebarItem(
          index: 4,
          icon: Icons.settings_outlined,
          title: 'Settings',
          isDrawer: isDrawer,
          onTap: () {
            if (isDrawer) Navigator.of(context).pop();
            _openQuickSettingsSheet();
          },
        ),

        const Spacer(),

        // Bottom Motivational Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF091416),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF14292D)),
          ),
          child: const Row(
            children: [
              Icon(Icons.eco_rounded, size: 18, color: mint),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '"Small steps make big progress."',
                  style: TextStyle(
                    color: mint,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String title,
    required bool isDrawer,
    VoidCallback? onTap,
  }) {
    final isSelected = _selectedNavIndex == index;

    return InkWell(
      onTap: () {
        if (isDrawer && onTap == null) Navigator.of(context).pop();
        if (onTap != null) {
          onTap();
        } else {
          setState(() => _selectedNavIndex = index);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D2522) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFF16473E), width: 1.2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected ? mint : textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? mint : textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mobile Bottom Navigation Bar
  Widget _buildMobileBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: sidebarBg,
        border: Border(
          top: BorderSide(color: sidebarBorder, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMobileNavItem(0, Icons.home_rounded, 'Home'),
              _buildMobileNavItem(1, Icons.bar_chart_rounded, 'Analytics'),
              _buildMobileNavItem(2, Icons.grid_view_rounded, 'Categories'),
              _buildMobileNavItem(
                  3, Icons.account_balance_wallet_outlined, 'Vaults',
                  onTap: () => _openAddMoneySuperModal(initialTab: 0)),
              _buildMobileNavItem(4, Icons.settings_outlined, 'Settings',
                  onTap: _openQuickSettingsSheet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(int index, IconData icon, String label,
      {VoidCallback? onTap}) {
    final isSelected = _selectedNavIndex == index;
    return InkWell(
      onTap: onTap ?? () => setState(() => _selectedNavIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? mint : textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? mint : textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 2. TOP HEADER BAR
  // ---------------------------------------------------------
  Widget _buildTopHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (isMobile) ...[
                Builder(
                  builder: (ctx) => IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.menu_rounded,
                        color: Colors.white, size: 22),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $_userName 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _selectedAccountId == null
                          ? "Consolidated Vault Liquidity"
                          : "${_accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => _accounts.first).name} View",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCircularIconBtn(
              icon: Icons.search_rounded,
              size: isMobile ? 32 : 36,
              onTap: () {},
            ),
            SizedBox(width: isMobile ? 6 : 10),
            _buildCircularIconBtn(
              icon: Icons.candlestick_chart_outlined,
              size: isMobile ? 32 : 36,
              onTap: () => setState(() => _selectedNavIndex = 1),
            ),
            SizedBox(width: isMobile ? 6 : 10),
            _buildCircularIconBtn(
              icon: Icons.settings_outlined,
              size: isMobile ? 32 : 36,
              onTap: _openQuickSettingsSheet,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    double size = 36,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: cardBorder, width: 1),
        ),
        child: Icon(icon, size: size * 0.47, color: textSecondary),
      ),
    );
  }

  // ---------------------------------------------------------
  // 3. MAIN HERO BALANCE CARD (Ultra-Clean & Streamlined)
  // ---------------------------------------------------------
  Widget _buildHeroCard(bool isMobile) {
    final isFiltered = _selectedAccountId != null;
    final activeAccount = isFiltered
        ? _accounts.firstWhere((a) => a.id == _selectedAccountId,
            orElse: () => _accounts.first)
        : null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [heroBgStart, heroBgEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: heroBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: mint.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Active Context & Quick Actions (+ Add Money, - Add Expense)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFiltered
                                ? (activeAccount?.color ?? mint)
                                : mint,
                            boxShadow: [
                              BoxShadow(
                                color: (isFiltered
                                        ? (activeAccount?.color ?? mint)
                                        : mint)
                                    .withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFiltered
                              ? '${activeAccount?.name} Balance'
                              : 'Total Consolidated Balance',
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$_currencySymbol${_activeRemainingBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 30 : 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Action Buttons: "+ Add" & "- Spend"
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _openAddMoneySuperModal(initialTab: 0),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 13,
                        vertical: isMobile ? 8 : 9,
                      ),
                      decoration: BoxDecoration(
                        color: mint,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: mint.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              size: 15, color: Color(0xFF061F1A)),
                          SizedBox(width: isMobile ? 3 : 5),
                          Text(
                            isMobile ? 'Add' : 'Add Money',
                            style: const TextStyle(
                              color: Color(0xFF061F1A),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _openAddSpendBottomSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 13,
                        vertical: isMobile ? 8 : 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_rounded,
                              size: 15, color: rose),
                          SizedBox(width: isMobile ? 3 : 5),
                          const Text(
                            'Spend',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 18),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _remainingRatio,
              minHeight: 6,
              backgroundColor: const Color(0xFF0E2522),
              valueColor: const AlwaysStoppedAnimation<Color>(mint),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Stats: Added vs Spent
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Starting / Added: $_currencySymbol${_activeStartingMoney.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Spent: -$_currencySymbol${_activeSpentTotal.toStringAsFixed(2)} (${(_remainingRatio * 100).toStringAsFixed(0)}% Left)',
                style: TextStyle(
                  color: _activeSpentTotal > 0 ? rose : textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // DEDICATED "MY ACCOUNTS & CASH" CAROUSEL
  // ---------------------------------------------------------
  Widget _buildAccountsSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Accounts & Cash',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedAccountId == null
                      ? 'Tap any card to filter transactions'
                      : 'Filtered by ${_accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => _accounts.first).name}',
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (_selectedAccountId != null) ...[
                  InkWell(
                    onTap: () => setState(() => _selectedAccountId = null),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.close_rounded,
                              size: 12, color: textSecondary),
                          SizedBox(width: 4),
                          Text(
                            'Show All',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: () => _openAddMoneySuperModal(initialTab: 1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D09C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00D09C).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded,
                            size: 13, color: Color(0xFF00D09C)),
                        SizedBox(width: 4),
                        Text(
                          'New Account',
                          style: TextStyle(
                            color: Color(0xFF00D09C),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Scrollable Cards List
        SizedBox(
          height: 122,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              // Card 0: All Accounts (Consolidated)
              _buildAccountCard(
                id: null,
                name: 'All Accounts',
                type: 'all',
                balance: _totalConsolidatedBalance,
                icon: Icons.account_balance_wallet_rounded,
                color: mint,
                isPrimary: false,
                isSelected: _selectedAccountId == null,
              ),
              const SizedBox(width: 10),

              // Account Cards
              ..._accounts.map((acc) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _buildAccountCard(
                    id: acc.id,
                    name: acc.name,
                    type: acc.type,
                    balance: acc.balance,
                    icon: acc.icon,
                    color: acc.color,
                    isPrimary: acc.isPrimary,
                    isSelected: _selectedAccountId == acc.id,
                  ),
                );
              }),

              // "+ Add Vault" Card
              _buildAddAccountActionCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard({
    required String? id,
    required String name,
    required String type,
    required double balance,
    required IconData icon,
    required Color color,
    required bool isPrimary,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedAccountId == id) {
            _selectedAccountId = null; // toggle back to all
          } else {
            _selectedAccountId = id;
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 175,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : cardBorder,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row: Icon + Primary Tag / Quick '+' Top-Up Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPrimary) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00D09C).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '⭐ PRIMARY',
                          style: TextStyle(
                            color: Color(0xFF00D09C),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (id != null) ...[
                      InkWell(
                        onTap: () => _openAddMoneySuperModal(
                          initialTab: 0,
                          preselectedAccountId: id,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            // Middle: Name & Subtitle
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  type == 'all' ? 'Consolidated' : type.toUpperCase(),
                  style: const TextStyle(
                    color: textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),

            // Bottom: Balance
            Text(
              '$_currencySymbol${balance.toStringAsFixed(0)}',
              style: TextStyle(
                color: isSelected ? color : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAccountActionCard() {
    return InkWell(
      onTap: () => _openAddMoneySuperModal(initialTab: 1),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 22, color: textSecondary),
            SizedBox(height: 6),
            Text(
              'Add Vault',
              style: TextStyle(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 4. ACTION ROW: 4 METRIC CARDS
  // ---------------------------------------------------------
  Widget _buildMetricCardsRow(bool isMobile) {
    final primary = _primaryAccount;
    final otherAccounts = _accounts.where((a) => a.id != primary?.id).toList();
    final secondary = otherAccounts.isNotEmpty ? otherAccounts.first : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.star_rounded,
                      iconColor: mint,
                      bgColor: const Color(0xFF0D2520),
                      label: primary?.name ?? 'Primary Bank',
                      value:
                          '$_currencySymbol${primary?.balance.toStringAsFixed(0) ?? '0'}',
                      isMobile: true,
                      onTap: primary != null
                          ? () => setState(() => _selectedAccountId = primary.id)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      icon: secondary?.icon ?? Icons.payments_rounded,
                      iconColor: secondary?.color ?? const Color(0xFF34D399),
                      bgColor: const Color(0xFF0A2218),
                      label: secondary?.name ?? 'Cash in Hand',
                      value:
                          '$_currencySymbol${secondary?.balance.toStringAsFixed(0) ?? '0'}',
                      isMobile: true,
                      onTap: secondary != null
                          ? () => setState(() => _selectedAccountId = secondary.id)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.receipt_long_rounded,
                      iconColor: indigo,
                      bgColor: const Color(0xFF141732),
                      label: 'Spends',
                      value: '${_filteredExpenses.length} Logged',
                      isMobile: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.pie_chart_outline_rounded,
                      iconColor: amber,
                      bgColor: const Color(0xFF2E2413),
                      label: 'Categories',
                      value: '$_categoriesCount Active',
                      isMobile: true,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.star_rounded,
                iconColor: mint,
                bgColor: const Color(0xFF0D2520),
                label: primary?.name ?? 'Primary Bank',
                value:
                    '$_currencySymbol${primary?.balance.toStringAsFixed(0) ?? '0'}',
                onTap: primary != null
                    ? () => setState(() => _selectedAccountId = primary.id)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: secondary?.icon ?? Icons.payments_rounded,
                iconColor: secondary?.color ?? const Color(0xFF34D399),
                bgColor: const Color(0xFF0A2218),
                label: secondary?.name ?? 'Cash in Hand',
                value:
                    '$_currencySymbol${secondary?.balance.toStringAsFixed(0) ?? '0'}',
                onTap: secondary != null
                    ? () => setState(() => _selectedAccountId = secondary.id)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.receipt_long_rounded,
                iconColor: indigo,
                bgColor: const Color(0xFF141732),
                label: 'Spends',
                value: '${_filteredExpenses.length} Logged',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.pie_chart_outline_rounded,
                iconColor: amber,
                bgColor: const Color(0xFF2E2413),
                label: 'Categories',
                value: '$_categoriesCount Active',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    bool isMobile = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 14,
          vertical: isMobile ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 28 : 32,
              height: isMobile ? 28 : 32,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: isMobile ? 14 : 16, color: iconColor),
            ),
            SizedBox(width: isMobile ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: isMobile ? 10 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: isMobile ? 14 : 16, color: textTertiary),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 5. FULL-WIDTH CTA BUTTON: + Add Spend / Expense
  // ---------------------------------------------------------
  Widget _buildAddSpendButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _openAddSpendBottomSheet,
        style: ElevatedButton.styleFrom(
          backgroundColor: mint,
          foregroundColor: const Color(0xFF061F1A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                size: 14,
                color: Color(0xFF061F1A),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Add Spend / Expense',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 6. RECENT SPENDS SECTION (Shows Paid-From Badge)
  // ---------------------------------------------------------
  Widget _buildRecentSpendsSection(bool isMobile) {
    final spends = _filteredExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Dropdown & record count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedAccountId == null
                  ? 'Recent Spends'
                  : 'Spends from ${_accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => _accounts.first).name}',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 15 : 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategoryFilter,
                      dropdownColor: cardBg,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: textSecondary),
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      items: ['All', 'Food', 'Transport', 'Bills', 'Shopping']
                          .map((val) => DropdownMenuItem(
                                value: val,
                                child: Text(val),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategoryFilter = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${spends.length} records',
                  style: const TextStyle(
                    color: textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: isMobile ? 12 : 16),

        if (spends.isEmpty)
          _buildEmptyState(isMobile)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: spends.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final expense = spends[index];
              final accountLabel = expense.accountName != null
                  ? ' • 🏦 ${expense.accountName}'
                  : '';

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isMobile ? 34 : 38,
                      height: isMobile ? 34 : 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        expense.icon,
                        color: mint,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${expense.category} • ${_formatTime(expense.date)}$accountLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textTertiary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '-$_currencySymbol${expense.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: rose,
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () => _deleteExpense(expense.id),
                          child: const Text(
                            'Refund',
                            style: TextStyle(
                              color: textTertiary,
                              fontSize: 10,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: isMobile ? 24 : 36, horizontal: isMobile ? 12 : 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isMobile ? 50 : 60,
                height: isMobile ? 50 : 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mint.withValues(alpha: 0.05),
                ),
              ),
              Container(
                width: isMobile ? 38 : 44,
                height: isMobile ? 42 : 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFF1E3339), width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    Icons.search_rounded,
                    size: isMobile ? 20 : 24,
                    color: mint,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),

          Text(
            'No spends recorded yet.',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 14 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your total $_currencySymbol${_activeRemainingBalance.toStringAsFixed(2)} is intact across your vaults.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tap "+ Add Spend / Expense" to log your first spend.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
            ),
          ),
          SizedBox(height: isMobile ? 10 : 14),

          Text(
            'Every ${_currencySymbol == '₹' ? 'rupee' : 'dollar'} tells a story',
            style: const TextStyle(
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
              color: Color(0xFF71828A),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }
}
