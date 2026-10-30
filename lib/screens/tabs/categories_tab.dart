import 'package:flutter/material.dart';
import '../../models/expense_item.dart';
import '../../theme/app_theme.dart';

class CategoriesTab extends StatefulWidget {
  final List<ExpenseItem> expenses;
  final String currencySymbol;
  final bool isMobile;
  final VoidCallback? onOpenDrawer;

  const CategoriesTab({
    super.key,
    required this.expenses,
    required this.currencySymbol,
    required this.isMobile,
    this.onOpenDrawer,
  });

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  final List<String> _knownCategories = [
    'Food',
    'Transport',
    'Bills',
    'Shopping',
    'Health',
    'Entertainment',
    'Education',
    'Investment',
    'Other',
  ];

  double get _totalExpenses =>
      widget.expenses.fold(0.0, (sum, item) => sum + item.amount);

  void _showCategoryDetails(String category) {
    final catExpenses =
        widget.expenses.where((e) => e.category == category).toList();
    final catTotal = catExpenses.fold(0.0, (sum, e) => sum + e.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      builder: (ctx) {
        final icon = ExpenseItem.iconFromCategory(category);
        final color = ExpenseItem.colorFromCategory(category);

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, size: 20, color: color),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${catExpenses.length} transactions logged',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '${widget.currencySymbol}${catTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  const SizedBox(height: 12),
                  if (catExpenses.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No spends recorded under this category.',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: catExpenses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = catExpenses[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${item.date.day}/${item.date.month}/${item.date.year}${item.accountName != null ? ' • 🏦 ${item.accountName}' : ''}',
                                      style: const TextStyle(
                                        color: AppTheme.textFaint,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '-${widget.currencySymbol}${item.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppTheme.rose,
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.isMobile;
    final total = _totalExpenses;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 14 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        'Expense Categories 🗂️',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap any category to inspect transaction history',
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
          const SizedBox(height: 20),

          // Categories Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isMobile ? 1.25 : 1.45,
            ),
            itemCount: _knownCategories.length,
            itemBuilder: (context, index) {
              final cat = _knownCategories[index];
              final catExpenses =
                  widget.expenses.where((e) => e.category == cat).toList();
              final catTotal =
                  catExpenses.fold(0.0, (sum, e) => sum + e.amount);
              final ratio = total > 0 ? (catTotal / total) : 0.0;
              final icon = ExpenseItem.iconFromCategory(cat);
              final color = ExpenseItem.colorFromCategory(cat);

              return InkWell(
                onTap: () => _showCategoryDetails(cat),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 16, color: color),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(ratio * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${catExpenses.length} spends',
                            style: const TextStyle(
                              color: AppTheme.textFaint,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${widget.currencySymbol}${catTotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: catTotal > 0 ? Colors.white : AppTheme.textFaint,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
