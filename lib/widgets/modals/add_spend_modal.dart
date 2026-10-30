import 'package:flutter/material.dart';
import '../../models/account_vault.dart';
import '../../models/expense_item.dart';
import '../../theme/app_theme.dart';

class AddSpendModal extends StatefulWidget {
  final List<AccountVault> accounts;
  final String currencySymbol;
  final String? initialAccountId;
  final void Function({
    required String title,
    required double amount,
    required String category,
    required IconData icon,
    required String accountId,
    required String accountName,
  }) onAddExpense;

  const AddSpendModal({
    super.key,
    required this.accounts,
    required this.currencySymbol,
    this.initialAccountId,
    required this.onAddExpense,
  });

  static Future<void> show({
    required BuildContext context,
    required List<AccountVault> accounts,
    required String currencySymbol,
    String? initialAccountId,
    required void Function({
      required String title,
      required double amount,
      required String category,
      required IconData icon,
      required String accountId,
      required String accountName,
    }) onAddExpense,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      builder: (_) => AddSpendModal(
        accounts: accounts,
        currencySymbol: currencySymbol,
        initialAccountId: initialAccountId,
        onAddExpense: onAddExpense,
      ),
    );
  }

  @override
  State<AddSpendModal> createState() => _AddSpendModalState();
}

class _AddSpendModalState extends State<AddSpendModal> {
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;

  late String _selectedAccountId;
  String _selectedCategory = 'Food';
  late IconData _selectedIcon;
  String? _errorMessage;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Food', 'icon': Icons.restaurant_outlined},
    {'name': 'Transport', 'icon': Icons.directions_car_outlined},
    {'name': 'Bills', 'icon': Icons.receipt_long_outlined},
    {'name': 'Shopping', 'icon': Icons.shopping_bag_outlined},
    {'name': 'Health', 'icon': Icons.medical_services_outlined},
    {'name': 'Entertainment', 'icon': Icons.movie_outlined},
    {'name': 'Education', 'icon': Icons.school_outlined},
    {'name': 'Investment', 'icon': Icons.trending_up_rounded},
    {'name': 'Other', 'icon': Icons.category_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _titleController = TextEditingController();

    if (widget.initialAccountId != null &&
        widget.accounts.any((a) => a.id == widget.initialAccountId)) {
      _selectedAccountId = widget.initialAccountId!;
    } else if (widget.accounts.isNotEmpty) {
      final primary = widget.accounts.where((a) => a.isPrimary);
      _selectedAccountId =
          primary.isNotEmpty ? primary.first.id : widget.accounts.first.id;
    } else {
      _selectedAccountId = '';
    }

    _selectedIcon = ExpenseItem.iconFromCategory(_selectedCategory);
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  AccountVault? get _currentAccount {
    final matches = widget.accounts.where((a) => a.id == _selectedAccountId);
    return matches.isNotEmpty
        ? matches.first
        : (widget.accounts.isNotEmpty ? widget.accounts.first : null);
  }

  void _handleSubmit() {
    final text = _amountController.text.trim();
    final amount = double.tryParse(text);

    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid spend amount greater than 0.';
      });
      return;
    }

    final activeAccount = _currentAccount;
    if (activeAccount == null) {
      setState(() {
        _errorMessage = 'Please select a valid account or vault.';
      });
      return;
    }

    widget.onAddExpense(
      title: _titleController.text.trim().isEmpty
          ? _selectedCategory
          : _titleController.text.trim(),
      amount: amount,
      category: _selectedCategory,
      icon: _selectedIcon,
      accountId: activeAccount.id,
      accountName: activeAccount.name,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final activeAccount = _currentAccount;
    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final isExceeding =
        activeAccount != null && enteredAmount > activeAccount.balance;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                const Text(
                  'Record Spend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppTheme.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Select source vault. Balances deduct in real-time with atomic sync.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),

            // Paid From Vault Selector
            const Text(
              'PAID FROM (VAULT / CASH)',
              style: TextStyle(
                color: AppTheme.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.accounts.map((acc) {
                final isSelected = _selectedAccountId == acc.id;
                return ChoiceChip(
                  selected: isSelected,
                  avatar: Icon(acc.icon,
                      size: 15,
                      color: isSelected ? Colors.black : acc.color),
                  label: Text(
                    '${acc.name} (${widget.currencySymbol}${acc.balance.toStringAsFixed(0)})',
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selectedColor: AppTheme.mint,
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppTheme.mint : AppTheme.cardBorder,
                      width: 1,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedAccountId = acc.id);
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
                color: AppTheme.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                prefixText: '${widget.currencySymbol} ',
                prefixStyle: const TextStyle(
                  color: AppTheme.mint,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                hintText: '0.00',
                hintStyle: const TextStyle(color: AppTheme.textFaint),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.mint),
                ),
              ),
            ),
            if (isExceeding) ...[
              const SizedBox(height: 6),
              Text(
                '⚠️ Note: Amount exceeds ${activeAccount.name} balance (${widget.currencySymbol}${activeAccount.balance.toStringAsFixed(0)})',
                style: const TextStyle(color: AppTheme.rose, fontSize: 11),
              ),
            ],
            const SizedBox(height: 16),

            // Quick Spend Presets
            Wrap(
              spacing: 8,
              children: [50.0, 100.0, 250.0, 500.0, 1000.0].map((val) {
                return InkWell(
                  onTap: () {
                    final curr =
                        double.tryParse(_amountController.text.trim()) ?? 0.0;
                    _amountController.text = (curr + val).toInt().toString();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(
                      '+${widget.currencySymbol}${val.toInt()}',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Spend Details / Note
            const Text(
              'SPEND DETAILS / NOTE',
              style: TextStyle(
                color: AppTheme.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Lunch, Coffee, Groceries, Metro...',
                hintStyle: const TextStyle(color: AppTheme.textFaint),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.mint),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Chips
            const Text(
              'CATEGORY',
              style: TextStyle(
                color: AppTheme.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['name'];
                return ChoiceChip(
                  selected: isSelected,
                  label: Text(
                    cat['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  avatar: Icon(
                    cat['icon'] as IconData,
                    size: 15,
                    color: isSelected ? Colors.black : AppTheme.textMuted,
                  ),
                  selectedColor: AppTheme.mint,
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppTheme.mint : AppTheme.cardBorder,
                      width: 1,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = cat['name'] as String;
                        _selectedIcon = cat['icon'] as IconData;
                      });
                    }
                  },
                );
              }).toList(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.rose, fontSize: 12),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mint,
                  foregroundColor: const Color(0xFF061F1A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleSubmit,
                child: Text(
                  activeAccount != null
                      ? 'Deduct From ${activeAccount.name} ⚡'
                      : 'Record Spend ⚡',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
