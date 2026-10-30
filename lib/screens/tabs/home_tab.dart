import 'package:flutter/material.dart';
import '../../models/account_vault.dart';
import '../../models/expense_item.dart';
import '../../theme/app_theme.dart';

class HomeTab extends StatefulWidget {
  final String userName;
  final String? userPhotoUrl;
  final String currencySymbol;
  final List<AccountVault> accounts;
  final List<ExpenseItem> expenses;
  final String? selectedAccountId;
  final bool isMobile;

  final VoidCallback onOpenAddSpend;
  final void Function(int initialTab, [String? accountId]) onOpenVaultAction;
  final void Function(String? accountId) onSelectAccount;
  final void Function(String expenseId) onDeleteExpense;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAnalytics;
  final VoidCallback? onOpenDrawer;

  const HomeTab({
    super.key,
    required this.userName,
    this.userPhotoUrl,
    required this.currencySymbol,
    required this.accounts,
    required this.expenses,
    required this.selectedAccountId,
    required this.isMobile,
    required this.onOpenAddSpend,
    required this.onOpenVaultAction,
    required this.onSelectAccount,
    required this.onDeleteExpense,
    required this.onOpenSettings,
    required this.onOpenAnalytics,
    this.onOpenDrawer,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _searchQuery = '';
  String _categoryFilter = 'All';
  bool _isSearching = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Dynamic Mathematical Calculations ---

  AccountVault? get _primaryAccount {
    final matches = widget.accounts.where((a) => a.isPrimary);
    if (matches.isNotEmpty) return matches.first;
    return widget.accounts.isNotEmpty ? widget.accounts.first : null;
  }

  double get _totalConsolidatedBalance =>
      widget.accounts.fold(0.0, (sum, acc) => sum + acc.balance);

  double get _activeRemainingBalance {
    if (widget.selectedAccountId == null) {
      return _totalConsolidatedBalance;
    }
    final match = widget.accounts.where((a) => a.id == widget.selectedAccountId);
    return match.isNotEmpty ? match.first.balance : 0.0;
  }

  double get _activeSpentTotal {
    if (widget.selectedAccountId == null) {
      return widget.expenses.fold(0.0, (sum, item) => sum + item.amount);
    }
    return widget.expenses
        .where((e) => e.accountId == widget.selectedAccountId)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _activeStartingMoney =>
      _activeRemainingBalance + _activeSpentTotal;

  double get _remainingRatio => _activeStartingMoney <= 0
      ? 0
      : (_activeRemainingBalance / _activeStartingMoney).clamp(0.0, 1.0);

  List<ExpenseItem> get _filteredExpenses {
    var list = widget.expenses;
    if (widget.selectedAccountId != null) {
      list = list.where((e) => e.accountId == widget.selectedAccountId).toList();
    }
    if (_categoryFilter != 'All') {
      list = list.where((e) => e.category == _categoryFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q) ||
            (e.accountName != null && e.accountName!.toLowerCase().contains(q));
      }).toList();
    }
    return list;
  }

  int get _categoriesCount {
    final cats = widget.expenses.map((e) => e.category).toSet();
    return cats.isEmpty ? 0 : cats.length;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.isMobile;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 14 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header Bar
          _buildTopHeader(isMobile),
          SizedBox(height: isMobile ? 14 : 18),

          // Search Bar (expandable)
          if (_isSearching) ...[
            _buildSearchBar(),
            SizedBox(height: isMobile ? 14 : 18),
          ],

          // 2. Hero Balance Card
          _buildHeroCard(isMobile),
          SizedBox(height: isMobile ? 16 : 20),

          // 3. Accounts & Cash Horizontal Carousel
          _buildAccountsSection(isMobile),
          SizedBox(height: isMobile ? 18 : 22),

          // 4. Metric Cards Row
          _buildMetricCardsRow(isMobile),
          SizedBox(height: isMobile ? 16 : 20),

          // 5. Add Spend CTA Button
          _buildAddSpendButton(),
          SizedBox(height: isMobile ? 20 : 24),

          // 6. Recent Spends Section
          _buildRecentSpendsSection(isMobile),
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isMobile) {
    final activeVaultName = widget.selectedAccountId == null
        ? 'Consolidated Vault Liquidity'
        : '${widget.accounts.firstWhere((a) => a.id == widget.selectedAccountId, orElse: () => widget.accounts.first).name} View';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (isMobile && widget.onOpenDrawer != null) ...[
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.menu_rounded,
                      color: Colors.white, size: 22),
                  onPressed: widget.onOpenDrawer,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, ${widget.userName} 👋',
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
                      activeVaultName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textMuted,
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
              icon: _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: _isSearching ? AppTheme.mint : AppTheme.textMuted,
              size: isMobile ? 32 : 36,
              onTap: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
            ),
            SizedBox(width: isMobile ? 6 : 10),
            _buildCircularIconBtn(
              icon: Icons.candlestick_chart_outlined,
              size: isMobile ? 32 : 36,
              onTap: widget.onOpenAnalytics,
            ),
            SizedBox(width: isMobile ? 6 : 10),
            _buildCircularIconBtn(
              icon: Icons.settings_outlined,
              size: isMobile ? 32 : 36,
              onTap: widget.onOpenSettings,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search spends by note, category, or vault...',
          hintStyle:
              const TextStyle(color: AppTheme.textFaint, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.mint, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppTheme.textMuted, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildCircularIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color color = AppTheme.textMuted,
    double size = 36,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.cardBorder, width: 1),
        ),
        child: Icon(icon, size: size * 0.47, color: color),
      ),
    );
  }

  Widget _buildHeroCard(bool isMobile) {
    final isFiltered = widget.selectedAccountId != null;
    final activeAccount = isFiltered
        ? widget.accounts.firstWhere((a) => a.id == widget.selectedAccountId,
            orElse: () => widget.accounts.first)
        : null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.heroBgStart, AppTheme.heroBgEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.heroBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mint.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                                ? (activeAccount?.color ?? AppTheme.mint)
                                : AppTheme.mint,
                            boxShadow: [
                              BoxShadow(
                                color: (isFiltered
                                        ? (activeAccount?.color ?? AppTheme.mint)
                                        : AppTheme.mint)
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
                            color: AppTheme.textMuted,
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
                        '${widget.currencySymbol}${_activeRemainingBalance.toStringAsFixed(2)}',
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => widget.onOpenVaultAction(0),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 13,
                        vertical: isMobile ? 8 : 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.mint,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.mint.withValues(alpha: 0.3),
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
                    onTap: widget.onOpenAddSpend,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 13,
                        vertical: isMobile ? 8 : 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_rounded,
                              size: 15, color: AppTheme.rose),
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

          // Ratio Progress Indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _remainingRatio,
              minHeight: 6,
              backgroundColor: const Color(0xFF0E2522),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mint),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Stats: Added vs Spent
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Starting / Added: ${widget.currencySymbol}${_activeStartingMoney.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Spent: -${widget.currencySymbol}${_activeSpentTotal.toStringAsFixed(2)} (${(_remainingRatio * 100).toStringAsFixed(0)}% Left)',
                style: TextStyle(
                  color: _activeSpentTotal > 0
                      ? AppTheme.rose
                      : AppTheme.textMuted,
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
                  widget.selectedAccountId == null
                      ? 'Tap any card to filter transactions'
                      : 'Filtered by ${widget.accounts.firstWhere((a) => a.id == widget.selectedAccountId, orElse: () => widget.accounts.first).name}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (widget.selectedAccountId != null) ...[
                  InkWell(
                    onTap: () => widget.onSelectAccount(null),
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
                              size: 12, color: AppTheme.textMuted),
                          SizedBox(width: 4),
                          Text(
                            'Show All',
                            style: TextStyle(
                              color: AppTheme.textMuted,
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
                  onTap: () => widget.onOpenVaultAction(1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.mint.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded,
                            size: 13, color: AppTheme.mint),
                        SizedBox(width: 4),
                        Text(
                          'New Vault',
                          style: TextStyle(
                            color: AppTheme.mint,
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
        SizedBox(
          height: 122,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              // Consolidated Card
              _buildAccountCard(
                id: null,
                name: 'All Accounts',
                type: 'all',
                balance: _totalConsolidatedBalance,
                icon: Icons.account_balance_wallet_rounded,
                color: AppTheme.mint,
                isPrimary: false,
                isSelected: widget.selectedAccountId == null,
              ),
              const SizedBox(width: 10),

              // Individual Vault Cards
              ...widget.accounts.map((acc) {
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
                    isSelected: widget.selectedAccountId == acc.id,
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
      onTap: () => widget.onSelectAccount(widget.selectedAccountId == id ? null : id),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 175,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorder,
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
                          color: AppTheme.mint.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '⭐ PRIMARY',
                          style: TextStyle(
                            color: AppTheme.mint,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (id != null) ...[
                      InkWell(
                        onTap: () => widget.onOpenVaultAction(0, id),
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
                    color: AppTheme.textFaint,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            Text(
              '${widget.currencySymbol}${balance.toStringAsFixed(0)}',
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
      onTap: () => widget.onOpenVaultAction(1),
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
                size: 22, color: AppTheme.textMuted),
            SizedBox(height: 6),
            Text(
              'Add Vault',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCardsRow(bool isMobile) {
    final primary = _primaryAccount;
    final otherAccounts =
        widget.accounts.where((a) => a.id != primary?.id).toList();
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
                      iconColor: AppTheme.mint,
                      bgColor: const Color(0xFF0D2520),
                      label: primary?.name ?? 'Primary Bank',
                      value:
                          '${widget.currencySymbol}${primary?.balance.toStringAsFixed(0) ?? '0'}',
                      isMobile: true,
                      onTap: primary != null
                          ? () => widget.onSelectAccount(primary.id)
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
                          '${widget.currencySymbol}${secondary?.balance.toStringAsFixed(0) ?? '0'}',
                      isMobile: true,
                      onTap: secondary != null
                          ? () => widget.onSelectAccount(secondary.id)
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
                      iconColor: AppTheme.indigo,
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
                      iconColor: AppTheme.amber,
                      bgColor: const Color(0xFF2E2413),
                      label: 'Categories',
                      value: '$_categoriesCount Active',
                      isMobile: true,
                      onTap: widget.onOpenAnalytics,
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
                iconColor: AppTheme.mint,
                bgColor: const Color(0xFF0D2520),
                label: primary?.name ?? 'Primary Bank',
                value:
                    '${widget.currencySymbol}${primary?.balance.toStringAsFixed(0) ?? '0'}',
                onTap: primary != null
                    ? () => widget.onSelectAccount(primary.id)
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
                    '${widget.currencySymbol}${secondary?.balance.toStringAsFixed(0) ?? '0'}',
                onTap: secondary != null
                    ? () => widget.onSelectAccount(secondary.id)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.receipt_long_rounded,
                iconColor: AppTheme.indigo,
                bgColor: const Color(0xFF141732),
                label: 'Spends',
                value: '${_filteredExpenses.length} Logged',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.pie_chart_outline_rounded,
                iconColor: AppTheme.amber,
                bgColor: const Color(0xFF2E2413),
                label: 'Categories',
                value: '$_categoriesCount Active',
                onTap: widget.onOpenAnalytics,
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
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder, width: 1),
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
                      color: AppTheme.textMuted,
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
                size: isMobile ? 14 : 16, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSpendButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: widget.onOpenAddSpend,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.mint,
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

  Widget _buildRecentSpendsSection(bool isMobile) {
    final spends = _filteredExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.selectedAccountId == null
                  ? 'Recent Spends'
                  : 'Spends from ${widget.accounts.firstWhere((a) => a.id == widget.selectedAccountId, orElse: () => widget.accounts.first).name}',
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
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _categoryFilter,
                      dropdownColor: AppTheme.cardBg,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: AppTheme.textMuted),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      items: [
                        'All',
                        'Food',
                        'Transport',
                        'Bills',
                        'Shopping',
                        'Health',
                        'Entertainment',
                        'Education',
                        'Investment',
                        'Other'
                      ]
                          .map((val) => DropdownMenuItem(
                                value: val,
                                child: Text(val),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _categoryFilter = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${spends.length} records',
                  style: const TextStyle(
                    color: AppTheme.textFaint,
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
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
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
                        color: AppTheme.mint,
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
                              color: AppTheme.textFaint,
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
                          '-${widget.currencySymbol}${expense.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppTheme.rose,
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () => widget.onDeleteExpense(expense.id),
                          child: const Text(
                            'Refund',
                            style: TextStyle(
                              color: AppTheme.textFaint,
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
    final hasSearch = _searchQuery.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: isMobile ? 24 : 36, horizontal: isMobile ? 12 : 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: isMobile ? 44 : 50,
            height: isMobile ? 44 : 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.mint.withValues(alpha: 0.08),
            ),
            child: Icon(
              hasSearch ? Icons.search_off_rounded : Icons.receipt_long_outlined,
              size: isMobile ? 22 : 26,
              color: AppTheme.mint,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            hasSearch ? 'No matching spends found.' : 'No spends recorded yet.',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 14 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasSearch
                ? 'Try searching for a different keyword or category.'
                : 'Your balance of ${widget.currencySymbol}${_activeRemainingBalance.toStringAsFixed(2)} is intact across your vaults.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
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
