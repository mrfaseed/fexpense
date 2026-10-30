import 'package:flutter/material.dart';
import '../../models/account_vault.dart';
import '../../models/expense_item.dart';
import '../../theme/app_theme.dart';

class AnalyticsTab extends StatefulWidget {
  final List<ExpenseItem> expenses;
  final List<AccountVault> accounts;
  final String currencySymbol;
  final bool isMobile;
  final VoidCallback? onOpenDrawer;

  const AnalyticsTab({
    super.key,
    required this.expenses,
    required this.accounts,
    required this.currencySymbol,
    required this.isMobile,
    this.onOpenDrawer,
  });

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  int _periodFilter = 0; // 0: All Time, 1: This Month, 2: This Week

  List<ExpenseItem> get _filteredExpenses {
    final now = DateTime.now();
    if (_periodFilter == 1) {
      // This Month
      return widget.expenses
          .where((e) => e.date.year == now.year && e.date.month == now.month)
          .toList();
    } else if (_periodFilter == 2) {
      // This Week (last 7 days)
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      return widget.expenses.where((e) => e.date.isAfter(sevenDaysAgo)).toList();
    }
    return widget.expenses;
  }

  double get _totalSpent =>
      _filteredExpenses.fold(0.0, (sum, item) => sum + item.amount);

  double get _averageSpend => _filteredExpenses.isEmpty
      ? 0.0
      : _totalSpent / _filteredExpenses.length;

  Map<String, double> get _categoryTotals {
    final map = <String, double>{};
    for (final exp in _filteredExpenses) {
      map[exp.category] = (map[exp.category] ?? 0.0) + exp.amount;
    }
    return map;
  }

  Map<String, double> get _vaultTotals {
    final map = <String, double>{};
    for (final exp in _filteredExpenses) {
      final vaultName = exp.accountName ?? 'Primary Vault';
      map[vaultName] = (map[vaultName] ?? 0.0) + exp.amount;
    }
    return map;
  }

  List<ExpenseItem> get _largestExpenses {
    final sorted = List<ExpenseItem>.from(_filteredExpenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.isMobile;
    final totalSpent = _totalSpent;
    final categoryTotals = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final vaultTotals = _vaultTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 14 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spending Intelligence 📊',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Deep analytical breakdown of your cashflow',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Period Filter Chips
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                _buildPeriodTab('All Time', 0),
                _buildPeriodTab('This Month', 1),
                _buildPeriodTab('This Week', 2),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Top Highlight Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Outflow',
                  value:
                      '${widget.currencySymbol}${totalSpent.toStringAsFixed(2)}',
                  subtitle: '${_filteredExpenses.length} transactions',
                  icon: Icons.trending_down_rounded,
                  accentColor: AppTheme.rose,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Average Spend',
                  value:
                      '${widget.currencySymbol}${_averageSpend.toStringAsFixed(2)}',
                  subtitle: 'per recorded spend',
                  icon: Icons.functions_rounded,
                  accentColor: AppTheme.mint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Category Spending Breakdown
          const Text(
            'Outflow by Category',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),

          if (categoryTotals.isEmpty)
            _buildEmptyCard('No category data in selected period')
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: categoryTotals.map((entry) {
                  final catName = entry.key;
                  final amount = entry.value;
                  final ratio = totalSpent > 0 ? (amount / totalSpent) : 0.0;
                  final color = ExpenseItem.colorFromCategory(catName);
                  final icon = ExpenseItem.iconFromCategory(catName);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(icon, size: 14, color: color),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  catName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${widget.currencySymbol}${amount.toStringAsFixed(2)} (${(ratio * 100).toStringAsFixed(1)}%)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),

          // Vault Utilization
          const Text(
            'Outflow by Source Vault',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),

          if (vaultTotals.isEmpty)
            _buildEmptyCard('No vault data recorded yet')
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: vaultTotals.map((entry) {
                  final vaultName = entry.key;
                  final amount = entry.value;
                  final ratio = totalSpent > 0 ? (amount / totalSpent) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.mint.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            size: 15,
                            color: AppTheme.mint,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vaultName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(ratio * 100).toStringAsFixed(1)}% of total period spend',
                                style: const TextStyle(
                                  color: AppTheme.textFaint,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${widget.currencySymbol}${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),

          // Top 5 Largest Spends
          const Text(
            'Largest Individual Spends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),

          if (_largestExpenses.isEmpty)
            _buildEmptyCard('No spends logged in this period')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _largestExpenses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _largestExpenses[index];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item.icon, size: 16, color: AppTheme.mint),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${item.category} • ${item.date.day}/${item.date.month}/${item.date.year}',
                              style: const TextStyle(
                                color: AppTheme.textFaint,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '-${widget.currencySymbol}${item.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.rose,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String label, int index) {
    final isSelected = _periodFilter == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _periodFilter = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF061F1A) : AppTheme.textMuted,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textFaint,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}
