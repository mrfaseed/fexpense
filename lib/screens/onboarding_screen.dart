import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account_vault.dart';
import '../services/app_reset_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_gradient_background.dart';
import '../widgets/border_beam_card.dart';
import 'expense_tracker_screen.dart';

class OnboardingAccountDraft {
  final String id;
  TextEditingController nameController;
  TextEditingController balanceController;
  String type; // 'bank', 'cash', 'savings', 'wallet'
  bool isPrimary;

  OnboardingAccountDraft({
    required this.id,
    required String name,
    required this.type,
    required double balance,
    this.isPrimary = false,
  })  : nameController = TextEditingController(text: name),
        balanceController = TextEditingController(
          text: balance % 1 == 0
              ? balance.toInt().toString()
              : balance.toStringAsFixed(0),
        );

  void dispose() {
    nameController.dispose();
    balanceController.dispose();
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();
  final _nameController = TextEditingController();

  int _currentStep = 0;
  String _selectedCurrency = '₹';
  String? _errorMessage;
  bool _isSaving = false;

  final List<Map<String, String>> _currencies = [
    {'symbol': '₹', 'name': 'INR', 'full': 'Indian Rupee'},
    {'symbol': '\$', 'name': 'USD', 'full': 'US Dollar'},
    {'symbol': '€', 'name': 'EUR', 'full': 'Euro'},
    {'symbol': '£', 'name': 'GBP', 'full': 'British Pound'},
    {'symbol': 'AED', 'name': 'AED', 'full': 'UAE Dirham'},
    {'symbol': '¥', 'name': 'JPY', 'full': 'Japanese Yen'},
  ];

  final List<OnboardingAccountDraft> _accountDrafts = [];

  @override
  void initState() {
    super.initState();
    final name = _authService.currentDisplayName;
    _nameController.text = name.isNotEmpty ? name : 'User';

    // Default setup: 2 accounts (Primary Bank ₹7,000 + Cash in Hand ₹400 = ₹7,400)
    _setPresetAccounts(2);
  }

  void _setPresetAccounts(int count) {
    for (final draft in _accountDrafts) {
      draft.dispose();
    }
    _accountDrafts.clear();

    if (count == 1) {
      _accountDrafts.add(
        OnboardingAccountDraft(
          id: 'acc_bank_1',
          name: 'Primary Bank',
          type: 'bank',
          balance: 7000.0,
          isPrimary: true,
        ),
      );
    } else if (count == 2) {
      _accountDrafts.add(
        OnboardingAccountDraft(
          id: 'acc_bank_1',
          name: 'Primary Bank',
          type: 'bank',
          balance: 7000.0,
          isPrimary: true,
        ),
      );
      _accountDrafts.add(
        OnboardingAccountDraft(
          id: 'acc_cash_1',
          name: 'Cash in Hand',
          type: 'cash',
          balance: 400.0,
          isPrimary: false,
        ),
      );
    } else if (count >= 3) {
      _accountDrafts.add(
        OnboardingAccountDraft(
          id: 'acc_bank_1',
          name: 'Primary Bank',
          type: 'bank',
          balance: 7000.0,
          isPrimary: true,
        ),
      );
      _accountDrafts.add(
        OnboardingAccountDraft(
          id: 'acc_cash_1',
          name: 'Cash in Hand',
          type: 'cash',
          balance: 400.0,
          isPrimary: false,
        ),
      );
      _accountDrafts.add(
        OnboardingAccountDraft(
          id: 'acc_savings_1',
          name: 'Savings Vault',
          type: 'savings',
          balance: 2000.0,
          isPrimary: false,
        ),
      );
    }

    for (final draft in _accountDrafts) {
      draft.balanceController.addListener(() => setState(() {}));
    }
    setState(() {});
  }

  void _addCustomAccount() {
    setState(() {
      final newIndex = _accountDrafts.length + 1;
      final draft = OnboardingAccountDraft(
        id: 'acc_custom_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Account $newIndex',
        type: 'bank',
        balance: 1000.0,
        isPrimary: _accountDrafts.isEmpty,
      );
      draft.balanceController.addListener(() => setState(() {}));
      _accountDrafts.add(draft);
    });
  }

  void _removeAccount(int index) {
    if (_accountDrafts.length <= 1) return;
    setState(() {
      final removed = _accountDrafts.removeAt(index);
      final wasPrimary = removed.isPrimary;
      removed.dispose();
      if (wasPrimary && _accountDrafts.isNotEmpty) {
        _accountDrafts.first.isPrimary = true;
      }
    });
  }

  void _setPrimaryAccount(int index) {
    setState(() {
      for (int i = 0; i < _accountDrafts.length; i++) {
        _accountDrafts[i].isPrimary = (i == index);
      }
    });
  }

  double get _totalConsolidatedStartingBalance {
    double sum = 0.0;
    for (final draft in _accountDrafts) {
      final val = double.tryParse(draft.balanceController.text.trim()) ?? 0.0;
      sum += val;
    }
    return sum;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    for (final draft in _accountDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _errorMessage = null);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please enter your name to continue.');
        return;
      }
      _goToStep(1);
    } else if (_currentStep == 1) {
      if (_accountDrafts.isEmpty) {
        setState(() => _errorMessage = 'Please add at least one account.');
        return;
      }
      // Ensure at least one primary
      if (!_accountDrafts.any((a) => a.isPrimary)) {
        _accountDrafts.first.isPrimary = true;
      }
      for (final draft in _accountDrafts) {
        if (draft.nameController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'All accounts must have a name.');
          return;
        }
        final bal = double.tryParse(draft.balanceController.text.trim());
        if (bal == null || bal < 0) {
          setState(() => _errorMessage =
              'Enter a valid balance for ${draft.nameController.text.trim()}.');
          return;
        }
      }
      _goToStep(2);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _handleCompleteSetup() async {
    final name = _nameController.text.trim();
    final totalBalance = _totalConsolidatedStartingBalance;
    final primaryAccount = _accountDrafts.firstWhere(
      (a) => a.isPrimary,
      orElse: () => _accountDrafts.first,
    );

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final uid = _authService.currentUid;
    final now = DateTime.now();

    // Prepare AccountVault model objects
    final List<AccountVault> vaultList = [];
    for (int i = 0; i < _accountDrafts.length; i++) {
      final draft = _accountDrafts[i];
      final bal = double.tryParse(draft.balanceController.text.trim()) ?? 0.0;
      final accName = draft.nameController.text.trim().isNotEmpty
          ? draft.nameController.text.trim()
          : 'Account ${i + 1}';

      final vault = AccountVault(
        id: 'vault_${now.millisecondsSinceEpoch}_$i',
        name: accName,
        type: draft.type,
        balance: bal,
        iconCode: AccountVault.defaultIconForType(draft.type).codePoint,
        colorValue: AccountVault.defaultColorForType(draft.type).toARGB32(),
        createdAt: now.add(Duration(milliseconds: i * 10)),
        isPrimary: draft.isPrimary,
      );
      vaultList.add(vault);
    }

    try {
      // Save User Profile to Cloud Firestore
      await FirestoreService().saveUserProfile(
        uid: uid,
        name: name,
        email: _authService.currentEmail,
        photoUrl: _authService.currentPhotoUrl,
        currencySymbol: _selectedCurrency,
        walletType: primaryAccount.nameController.text.trim(),
        totalBudget: totalBalance,
      );

      // Save each Account to Cloud Firestore
      for (final vault in vaultList) {
        await FirestoreService().saveAccount(uid, vault);
      }
    } catch (e) {
      debugPrint('Firestore save error during onboarding: $e');
    }

    // Save local cache for fast instant offline launch
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('currency_symbol', _selectedCurrency);
    await prefs.setString(
        'wallet_type', primaryAccount.nameController.text.trim());
    await prefs.setDouble('total_budget', totalBalance);
    await prefs.setStringList(
        'accounts_cache', vaultList.map((a) => jsonEncode(a.toJson())).toList());
    await prefs.setBool('is_onboarded', true);

    if (!mounted) return;

    setState(() => _isSaving = false);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ExpenseTrackerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AiGradientBackground(
        intensity: 0.95,
        child: SafeArea(
          child: Center(
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main Floating Card
                      BorderBeamCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Header: Step Indicator & Actions
                            _buildTopNavigation(),
                            const SizedBox(height: 20),

                            // Dynamic Step Content
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: SizedBox(
                                height: 530,
                                child: PageView(
                                  controller: _pageController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  onPageChanged: (page) {
                                    setState(() {
                                      _currentStep = page;
                                      _errorMessage = null;
                                    });
                                  },
                                  children: [
                                    _buildStep1Identity(),
                                    _buildStep2Accounts(),
                                    _buildStep3Summary(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Minimal developer footer
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Built by Faseed for Faseed',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('•',
                                style: TextStyle(
                                    color: AppTheme.textTertiary, fontSize: 12)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: AppTheme.border,
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'v2.0 Multi-Account',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.rose.withValues(alpha: 0.8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                          ),
                          icon: const Icon(Icons.delete_forever_outlined,
                              size: 14),
                          label: const Text(
                            'Clear All & Start Fresh',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () =>
                              AppResetService.confirmAndReset(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Header: 3-Pill Step Indicator + Back Button + Reset Button
  // ---------------------------------------------------------
  Widget _buildTopNavigation() {
    return Row(
      children: [
        // Back Button
        AnimatedOpacity(
          opacity: _currentStep > 0 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: _currentStep == 0,
            child: InkWell(
              onTap: _prevStep,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 3-Segment Progress Bar
        Expanded(
          child: Row(
            children: List.generate(3, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              return Expanded(
                flex: isActive ? 2 : 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isActive
                        ? const Color(0xFF00D09C)
                        : (isCompleted
                            ? const Color(0xFF10B981)
                            : Colors.white.withValues(alpha: 0.12)),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00D09C)
                                  .withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),

        // Clear All Shortcut
        IconButton(
          tooltip: 'Clear All & Start Fresh',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.delete_sweep_outlined,
            size: 19,
            color: AppTheme.textTertiary.withValues(alpha: 0.7),
          ),
          onPressed: () => AppResetService.confirmAndReset(context),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // STEP 1: IDENTITY & CURRENCY
  // ---------------------------------------------------------
  Widget _buildStep1Identity() {
    final photoUrl = _authService.currentPhotoUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00D09C).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(48),
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _defaultAvatar(),
                      )
                    : _defaultAvatar(),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 1 of 3',
                    style: TextStyle(
                      color: Color(0xFF00D09C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your Identity',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text(
          'Personalize how FExpense addresses you and sets your baseline operating currency.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          'YOUR NAME',
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'e.g. Faseed',
            prefixIcon: const Icon(Icons.badge_outlined,
                color: Color(0xFF00D09C), size: 18),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.25),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF00D09C), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          'OPERATING CURRENCY',
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _currencies.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.8,
            ),
            itemBuilder: (context, index) {
              final curr = _currencies[index];
              final isSelected = _selectedCurrency == curr['symbol'];
              return InkWell(
                onTap: () {
                  setState(() => _selectedCurrency = curr['symbol']!);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00D09C).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00D09C)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        curr['symbol']!,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF00D09C)
                              : AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        curr['name']!,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (_errorMessage != null) ...[
          _buildErrorBadge(_errorMessage!),
          const SizedBox(height: 10),
        ],

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D09C),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Set Up Accounts & Liquidity',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // STEP 2: ACCOUNTS, BALANCES & PRIMARY SELECTION
  // ---------------------------------------------------------
  Widget _buildStep2Accounts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step 2 of 3',
                  style: TextStyle(
                    color: Color(0xFF00D09C),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your Accounts & Cash',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            // Live Total Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00D09C).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF00D09C).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Total: $_selectedCurrency${_totalConsolidatedStartingBalance.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF00D09C),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        const Text(
          'How many accounts do you hold? Customize account names, set starting balances, and choose your primary account.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),

        // Quick Account Count Selector
        Row(
          children: [
            _buildCountPresetBtn('1 Account', 1, _accountDrafts.length == 1),
            const SizedBox(width: 6),
            _buildCountPresetBtn(
                '2 (Bank + Cash)', 2, _accountDrafts.length == 2,
                badge: 'Recommended'),
            const SizedBox(width: 6),
            _buildCountPresetBtn('3 Vaults', 3, _accountDrafts.length == 3),
            const SizedBox(width: 6),
            InkWell(
              onTap: _addCustomAccount,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 13, color: Color(0xFF00D09C)),
                    SizedBox(width: 2),
                    Text(
                      'Add',
                      style: TextStyle(
                          color: Color(0xFF00D09C),
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Dynamic List of Account Draft Cards
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: _accountDrafts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final draft = _accountDrafts[index];
              return _buildAccountDraftCard(draft, index);
            },
          ),
        ),

        if (_errorMessage != null) ...[
          _buildErrorBadge(_errorMessage!),
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D09C),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Review & Confirm ⚡',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountPresetBtn(String label, int count, bool isSelected,
      {String? badge}) {
    return Expanded(
      child: InkWell(
        onTap: () => _setPresetAccounts(count),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00D09C).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00D09C)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(height: 1),
                Text(
                  badge,
                  style: const TextStyle(
                    color: Color(0xFF00D09C),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDraftCard(OnboardingAccountDraft draft, int index) {
    final isPrimary = draft.isPrimary;
    final color = AccountVault.defaultColorForType(draft.type);
    final icon = AccountVault.defaultIconForType(draft.type);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPrimary
            ? const Color(0xFF00D09C).withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary
              ? const Color(0xFF00D09C).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: isPrimary ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Type icon, Type dropdown, Primary Account tag, Delete
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),

              // Account Type Selector
              DropdownButton<String>(
                value: draft.type,
                dropdownColor: const Color(0xFF131716),
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down,
                    color: AppTheme.textSecondary, size: 18),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash in Hand')),
                  DropdownMenuItem(value: 'savings', child: Text('Savings')),
                  DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      draft.type = val;
                    });
                  }
                },
              ),

              const Spacer(),

              // Primary Account Chip / Toggle
              InkWell(
                onTap: () => _setPrimaryAccount(index),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? const Color(0xFF00D09C)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPrimary
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 13,
                        color: isPrimary ? Colors.black : AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPrimary ? 'Primary' : 'Set Primary',
                        style: TextStyle(
                          color:
                              isPrimary ? Colors.black : AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_accountDrafts.length > 1) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _removeAccount(index),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: AppTheme.rose.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Name input + Starting Balance input
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: draft.nameController,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Account Name',
                    labelStyle: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.25),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFF00D09C), width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: draft.balanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: Color(0xFF00D09C),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Balance',
                    prefixText: '$_selectedCurrency ',
                    prefixStyle: const TextStyle(
                        color: Color(0xFF00D09C), fontWeight: FontWeight.w700),
                    labelStyle: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.25),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFF00D09C), width: 1.2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // STEP 3: REVIEW & LAUNCH
  // ---------------------------------------------------------
  Widget _buildStep3Summary() {
    final primaryAccount = _accountDrafts.firstWhere(
      (a) => a.isPrimary,
      orElse: () => _accountDrafts.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3 of 3',
          style: TextStyle(
            color: Color(0xFF00D09C),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Ready to Launch 🚀',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Here is your liquidity snapshot, ${_nameController.text.trim()}. Everything will sync live to Cloud Firestore.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Glowing Consolidated Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D2822), Color(0xFF061814)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF00D09C).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D09C).withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONSOLIDATED STARTING CAPITAL',
                style: TextStyle(
                  color: Color(0xFF8AE8D0),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_selectedCurrency${_totalConsolidatedStartingBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 12),

              // Primary Account Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D09C).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.star_rounded,
                        size: 15, color: Color(0xFF00D09C)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Primary Account (Default for Spends)',
                          style: TextStyle(
                              color: AppTheme.textTertiary, fontSize: 10),
                        ),
                        Text(
                          primaryAccount.nameController.text.trim(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$_selectedCurrency${(double.tryParse(primaryAccount.balanceController.text.trim()) ?? 0.0).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF00D09C),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Breakdown of accounts
        const Text(
          'ACCOUNT BREAKDOWN',
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: _accountDrafts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final draft = _accountDrafts[index];
              final bal =
                  double.tryParse(draft.balanceController.text.trim()) ?? 0.0;
              final color = AccountVault.defaultColorForType(draft.type);
              final icon = AccountVault.defaultIconForType(draft.type);

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        draft.nameController.text.trim(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (draft.isPrimary) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D09C).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PRIMARY',
                          style: TextStyle(
                              color: Color(0xFF00D09C),
                              fontSize: 9,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '$_selectedCurrency${bal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        if (_errorMessage != null) ...[
          _buildErrorBadge(_errorMessage!),
          const SizedBox(height: 8),
        ],

        // Enter Dashboard CTA
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleCompleteSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D09C),
              foregroundColor: Colors.black,
              disabledBackgroundColor:
                  const Color(0xFF00D09C).withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Launch Dashboard ⚡',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: const Color(0xFF1E293B),
      child: const Icon(
        Icons.person_rounded,
        color: Color(0xFF00D09C),
        size: 26,
      ),
    );
  }

  Widget _buildErrorBadge(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.rose.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.rose, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.rose,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
