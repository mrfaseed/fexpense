import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account_vault.dart';
import '../models/expense_item.dart';
import '../services/app_reset_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modals/add_spend_modal.dart';
import '../widgets/modals/vault_action_modal.dart';
import 'google_auth_screen.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/categories_tab.dart';
import 'tabs/home_tab.dart';

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

  int _selectedNavIndex = 0; // 0: Home, 1: Analytics, 2: Categories
  String? _selectedAccountId; // null means "All Vaults"

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
              _autoMigrateInitialAccounts(uid, _totalBudget);
            } else {
              setState(() => _accounts = remoteAccounts);
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
            setState(() => _expenses = remoteExpenses);
            _persistLocalExpenses();
          }
        },
        onError: (err) {
          debugPrint('Firestore expenses stream error: $err');
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
    const cashBalance = 400.0;

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
    setState(() => _accounts = list);
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

  // ---------------------------------------------------------
  // ATOMIC BUSINESS LOGIC ACTIONS
  // ---------------------------------------------------------

  void _handleAddExpense({
    required String title,
    required double amount,
    required String category,
    required IconData icon,
    required String accountId,
    required String accountName,
  }) async {
    final item = ExpenseItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      category: category,
      icon: icon,
      date: DateTime.now(),
      accountId: accountId,
      accountName: accountName,
    );

    final accIndex = _accounts.indexWhere((a) => a.id == accountId);
    double? newBal;

    if (accIndex != -1) {
      final acc = _accounts[accIndex];
      newBal = (acc.balance - amount).clamp(-99999999.0, 99999999.0);
      final updatedAcc = acc.copyWith(balance: newBal);
      setState(() {
        _accounts[accIndex] = updatedAcc;
        _expenses.insert(0, item);
      });
    } else {
      setState(() {
        _expenses.insert(0, item);
      });
    }

    _persistLocalAccounts();
    _persistLocalExpenses();

    final uid = _authService.currentUid;
    try {
      await _firestoreService.addExpenseWithBalance(
        uid: uid,
        item: item,
        accountId: accIndex != -1 ? accountId : null,
        newBalance: newBal,
      );
    } catch (e) {
      debugPrint('Error adding expense atomically: $e');
    }
  }

  void _handleDeleteExpense(String id) async {
    final itemIndex = _expenses.indexWhere((e) => e.id == id);
    if (itemIndex == -1) return; // Guard against StateError

    final item = _expenses[itemIndex];
    double? newBal;
    String? accId;

    if (item.accountId != null) {
      final accIndex = _accounts.indexWhere((a) => a.id == item.accountId);
      if (accIndex != -1) {
        final acc = _accounts[accIndex];
        newBal = acc.balance + item.amount;
        accId = item.accountId;
        setState(() {
          _accounts[accIndex] = acc.copyWith(balance: newBal);
          _expenses.removeAt(itemIndex);
        });
      } else {
        setState(() => _expenses.removeAt(itemIndex));
      }
    } else {
      setState(() => _expenses.removeAt(itemIndex));
    }

    _persistLocalAccounts();
    _persistLocalExpenses();

    final uid = _authService.currentUid;
    try {
      await _firestoreService.deleteExpenseWithRefund(
        uid: uid,
        expenseId: id,
        accountId: accId,
        newBalance: newBal,
      );
    } catch (e) {
      debugPrint('Error deleting expense: $e');
    }
  }

  Future<void> _handleDeposit(String accountId, double amount) async {
    final targetIndex = _accounts.indexWhere((a) => a.id == accountId);
    if (targetIndex != -1) {
      final target = _accounts[targetIndex];
      final newBal = target.balance + amount;
      setState(() {
        _accounts[targetIndex] = target.copyWith(balance: newBal);
      });
      _persistLocalAccounts();

      final uid = _authService.currentUid;
      await _firestoreService.updateAccountBalance(uid, target.id, newBal);
    }
  }

  Future<void> _handleCreateVault(
      String name, String type, double startingBalance) async {
    final newAcc = AccountVault(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: type,
      balance: startingBalance,
      iconCode: AccountVault.defaultIconForType(type).codePoint,
      colorValue: AccountVault.defaultColorForType(type).toARGB32(),
      createdAt: DateTime.now(),
    );

    setState(() => _accounts.add(newAcc));
    _persistLocalAccounts();

    final uid = _authService.currentUid;
    await _firestoreService.saveAccount(uid, newAcc);
  }

  Future<void> _handleTransfer(
      String sourceId, String destId, double amount) async {
    final sIndex = _accounts.indexWhere((a) => a.id == sourceId);
    final dIndex = _accounts.indexWhere((a) => a.id == destId);

    if (sIndex != -1 && dIndex != -1) {
      final sourceAcc = _accounts[sIndex];
      final destAcc = _accounts[dIndex];
      final newSourceBal = sourceAcc.balance - amount;
      final newDestBal = destAcc.balance + amount;

      setState(() {
        _accounts[sIndex] = sourceAcc.copyWith(balance: newSourceBal);
        _accounts[dIndex] = destAcc.copyWith(balance: newDestBal);
      });
      _persistLocalAccounts();

      final uid = _authService.currentUid;
      await _firestoreService.transferVaultFunds(
        uid: uid,
        sourceId: sourceAcc.id,
        newSourceBalance: newSourceBal,
        destId: destAcc.id,
        newDestBalance: newDestBal,
      );
    }
  }

  // ---------------------------------------------------------
  // MODALS & NAVIGATION
  // ---------------------------------------------------------

  void _openAddSpend() {
    AddSpendModal.show(
      context: context,
      accounts: _accounts,
      currencySymbol: _currencySymbol,
      initialAccountId: _selectedAccountId,
      onAddExpense: _handleAddExpense,
    );
  }

  void _openVaultAction(int initialTab, [String? preselectedAccountId]) {
    VaultActionModal.show(
      context: context,
      initialTab: initialTab,
      accounts: _accounts,
      currencySymbol: _currencySymbol,
      preselectedAccountId: preselectedAccountId,
      onDeposit: _handleDeposit,
      onCreateVault: _handleCreateVault,
      onTransfer: _handleTransfer,
    );
  }

  void _openQuickSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.cardBorder),
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
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.heroBorder,
                    backgroundImage: _userPhotoUrl != null
                        ? NetworkImage(_userPhotoUrl!)
                        : null,
                    child: _userPhotoUrl == null
                        ? const Icon(Icons.person, color: AppTheme.mint)
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
                              : 'Connected via Google Account',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
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
                      color: AppTheme.mint, size: 20),
                ),
                title: const Text('Manage Liquidity Vaults',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppTheme.textMuted),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openVaultAction(1);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.rose.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_sweep_outlined,
                      color: AppTheme.rose, size: 20),
                ),
                title: const Text('Factory Reset App (Clear All)',
                    style: TextStyle(color: AppTheme.rose, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppTheme.textMuted),
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
                trailing: const Icon(Icons.chevron_right,
                    color: AppTheme.textMuted),
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

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.cardBorder),
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
          'You will be signed out from ${_authService.currentEmail.isNotEmpty ? _authService.currentEmail : "this device"}. All multi-account vaults and expenses are securely saved in Firebase.',
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(90, 40),
              backgroundColor: AppTheme.rose,
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
                      (context, animation, secondaryAnimation, child) =>
                          FadeTransition(opacity: animation, child: child),
                ),
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.mint),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 820;
    final isMobile = screenWidth < 600;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgDark,
      drawer: !isDesktop
          ? Drawer(
              backgroundColor: AppTheme.sidebarBg,
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
            if (isDesktop) _buildSidebar(),
            Expanded(
              child: IndexedStack(
                index: _selectedNavIndex,
                children: [
                  // Tab 0: Home Dashboard
                  HomeTab(
                    userName: _userName,
                    userPhotoUrl: _userPhotoUrl,
                    currencySymbol: _currencySymbol,
                    accounts: _accounts,
                    expenses: _expenses,
                    selectedAccountId: _selectedAccountId,
                    isMobile: isMobile,
                    onOpenAddSpend: _openAddSpend,
                    onOpenVaultAction: _openVaultAction,
                    onSelectAccount: (accId) =>
                        setState(() => _selectedAccountId = accId),
                    onDeleteExpense: _handleDeleteExpense,
                    onOpenSettings: _openQuickSettingsSheet,
                    onOpenAnalytics: () =>
                        setState(() => _selectedNavIndex = 1),
                    onOpenDrawer: () =>
                        _scaffoldKey.currentState?.openDrawer(),
                  ),

                  // Tab 1: Analytics Dashboard
                  AnalyticsTab(
                    expenses: _expenses,
                    accounts: _accounts,
                    currencySymbol: _currencySymbol,
                    isMobile: isMobile,
                    onOpenDrawer: () =>
                        _scaffoldKey.currentState?.openDrawer(),
                  ),

                  // Tab 2: Categories Dashboard
                  CategoriesTab(
                    expenses: _expenses,
                    currencySymbol: _currencySymbol,
                    isMobile: isMobile,
                    onOpenDrawer: () =>
                        _scaffoldKey.currentState?.openDrawer(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // NAVIGATION BAR & SIDEBAR (Desktop & Mobile)
  // ---------------------------------------------------------

  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBg,
        border: Border(
          right: BorderSide(color: AppTheme.sidebarBorder, width: 1.2),
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
                    color: AppTheme.textFaint,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Navigation Items
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
          title: 'Budgets & Vaults',
          isDrawer: isDrawer,
          onTap: () {
            if (isDrawer) Navigator.of(context).pop();
            _openVaultAction(0);
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

        // Bottom Motivational Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF091416),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF14292D)),
          ),
          child: const Row(
            children: [
              Icon(Icons.eco_rounded, size: 18, color: AppTheme.mint),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '"Small steps make big financial progress."',
                  style: TextStyle(
                    color: AppTheme.mint,
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
              color: isSelected ? AppTheme.mint : AppTheme.textMuted,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppTheme.mint : AppTheme.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBg,
        border: Border(
          top: BorderSide(color: AppTheme.sidebarBorder, width: 1),
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
                3,
                Icons.account_balance_wallet_outlined,
                'Vaults',
                onTap: () => _openVaultAction(0),
              ),
              _buildMobileNavItem(
                4,
                Icons.settings_outlined,
                'Settings',
                onTap: _openQuickSettingsSheet,
              ),
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
              color: isSelected ? AppTheme.mint : AppTheme.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.mint : AppTheme.textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
