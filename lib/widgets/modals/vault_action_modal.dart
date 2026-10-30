import 'package:flutter/material.dart';
import '../../models/account_vault.dart';
import '../../theme/app_theme.dart';

class VaultActionModal extends StatefulWidget {
  final int initialTab; // 0: Deposit, 1: New Vault, 2: Transfer
  final List<AccountVault> accounts;
  final String currencySymbol;
  final String? preselectedAccountId;

  final Future<void> Function(String accountId, double amount) onDeposit;
  final Future<void> Function(String name, String type, double startingBalance)
      onCreateVault;
  final Future<void> Function(String sourceId, String destId, double amount)
      onTransfer;

  const VaultActionModal({
    super.key,
    this.initialTab = 0,
    required this.accounts,
    required this.currencySymbol,
    this.preselectedAccountId,
    required this.onDeposit,
    required this.onCreateVault,
    required this.onTransfer,
  });

  static Future<void> show({
    required BuildContext context,
    int initialTab = 0,
    required List<AccountVault> accounts,
    required String currencySymbol,
    String? preselectedAccountId,
    required Future<void> Function(String accountId, double amount) onDeposit,
    required Future<void> Function(
            String name, String type, double startingBalance)
        onCreateVault,
    required Future<void> Function(
            String sourceId, String destId, double amount)
        onTransfer,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      builder: (_) => VaultActionModal(
        initialTab: initialTab,
        accounts: accounts,
        currencySymbol: currencySymbol,
        preselectedAccountId: preselectedAccountId,
        onDeposit: onDeposit,
        onCreateVault: onCreateVault,
        onTransfer: onTransfer,
      ),
    );
  }

  @override
  State<VaultActionModal> createState() => _VaultActionModalState();
}

class _VaultActionModalState extends State<VaultActionModal> {
  late int _currentTab;

  // Controllers
  late final TextEditingController _depositController;
  late final TextEditingController _vaultNameController;
  late final TextEditingController _vaultBalController;
  late final TextEditingController _transferAmountController;

  // State values
  late String _depositAccountId;
  String _selectedVaultType = 'bank';
  late String _transferSourceId;
  late String _transferDestId;

  String? _modalError;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;

    _depositController = TextEditingController();
    _vaultNameController = TextEditingController();
    _vaultBalController = TextEditingController();
    _transferAmountController = TextEditingController();

    // Initialize deposit account
    if (widget.preselectedAccountId != null &&
        widget.accounts.any((a) => a.id == widget.preselectedAccountId)) {
      _depositAccountId = widget.preselectedAccountId!;
    } else if (widget.accounts.isNotEmpty) {
      final primary = widget.accounts.where((a) => a.isPrimary);
      _depositAccountId =
          primary.isNotEmpty ? primary.first.id : widget.accounts.first.id;
    } else {
      _depositAccountId = '';
    }

    // Initialize transfer source and destination
    _transferSourceId =
        widget.accounts.isNotEmpty ? widget.accounts.first.id : '';
    _transferDestId = widget.accounts.length > 1
        ? widget.accounts[1].id
        : (widget.accounts.isNotEmpty ? widget.accounts.first.id : '');
  }

  @override
  void dispose() {
    _depositController.dispose();
    _vaultNameController.dispose();
    _vaultBalController.dispose();
    _transferAmountController.dispose();
    super.dispose();
  }

  Future<void> _handleDeposit() async {
    final amount = double.tryParse(_depositController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _modalError = 'Please enter a valid deposit amount.');
      return;
    }

    if (!widget.accounts.any((a) => a.id == _depositAccountId)) {
      setState(() => _modalError = 'Please select a valid vault to deposit into.');
      return;
    }

    setState(() {
      _modalError = null;
      _isProcessing = true;
    });

    try {
      await widget.onDeposit(_depositAccountId, amount);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _modalError = 'Failed to deposit: $e';
        });
      }
    }
  }

  Future<void> _handleCreateVault() async {
    final name = _vaultNameController.text.trim();
    final startingBal =
        double.tryParse(_vaultBalController.text.trim()) ?? 0.0;

    if (name.isEmpty) {
      setState(() => _modalError = 'Please enter a name for the new vault.');
      return;
    }

    setState(() {
      _modalError = null;
      _isProcessing = true;
    });

    try {
      await widget.onCreateVault(name, _selectedVaultType, startingBal);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _modalError = 'Failed to create vault: $e';
        });
      }
    }
  }

  Future<void> _handleTransfer() async {
    if (_transferSourceId == _transferDestId) {
      setState(() => _modalError =
          'Source and destination vaults must be different.');
      return;
    }

    final amount = double.tryParse(_transferAmountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _modalError = 'Please enter a valid transfer amount.');
      return;
    }

    final sourceAcc =
        widget.accounts.firstWhere((a) => a.id == _transferSourceId);
    if (sourceAcc.balance < amount) {
      setState(() => _modalError =
          'Insufficient balance in ${sourceAcc.name} (${widget.currencySymbol}${sourceAcc.balance.toStringAsFixed(0)} available).');
      return;
    }

    setState(() {
      _modalError = null;
      _isProcessing = true;
    });

    try {
      await widget.onTransfer(_transferSourceId, _transferDestId, amount);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _modalError = 'Failed to transfer: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
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
                      color: AppTheme.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
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
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  _buildTab(
                    label: 'Deposit',
                    icon: Icons.add_circle_outline_rounded,
                    index: 0,
                  ),
                  _buildTab(
                    label: 'New Vault',
                    icon: Icons.account_balance_outlined,
                    index: 1,
                  ),
                  _buildTab(
                    label: 'Transfer',
                    icon: Icons.swap_horiz_rounded,
                    index: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tab 0: DEPOSIT
            if (_currentTab == 0) ...[
              const Text(
                'DEPOSIT TARGET VAULT',
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
                  final isSelected = _depositAccountId == acc.id;
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
                    backgroundColor: AppTheme.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                          color:
                              isSelected ? AppTheme.mint : AppTheme.cardBorder),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _depositAccountId = acc.id);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'AMOUNT TO ADD',
                style: TextStyle(
                  color: AppTheme.textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _depositController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '+${widget.currencySymbol} ',
                  prefixStyle: const TextStyle(
                      color: AppTheme.mint,
                      fontSize: 22,
                      fontWeight: FontWeight.w700),
                  hintText: '1000',
                  hintStyle: const TextStyle(color: AppTheme.textFaint),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.mint),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [500.0, 1000.0, 5000.0, 10000.0].map((val) {
                  return InkWell(
                    onTap: () {
                      final curr =
                          double.tryParse(_depositController.text) ?? 0.0;
                      _depositController.text =
                          (curr + val).toInt().toString();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mint,
                    foregroundColor: const Color(0xFF061F1A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _handleDeposit,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Add Funds to Vault ⚡',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ],

            // Tab 1: NEW VAULT
            if (_currentTab == 1) ...[
              const Text(
                'VAULT NAME',
                style: TextStyle(
                  color: AppTheme.textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _vaultNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. HDFC Bank, Cash in Hand, Savings...',
                  hintStyle: const TextStyle(color: AppTheme.textFaint),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.mint),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'VAULT TYPE',
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
                children: ['bank', 'cash', 'savings', 'wallet'].map((t) {
                  final isSelected = _selectedVaultType == t;
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
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    selectedColor: AppTheme.mint,
                    backgroundColor: AppTheme.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                          color:
                              isSelected ? AppTheme.mint : AppTheme.cardBorder),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedVaultType = t);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text(
                'STARTING BALANCE',
                style: TextStyle(
                  color: AppTheme.textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _vaultBalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '${widget.currencySymbol} ',
                  prefixStyle: const TextStyle(
                      color: AppTheme.mint,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                  hintText: '0.00',
                  hintStyle: const TextStyle(color: AppTheme.textFaint),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.mint),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mint,
                    foregroundColor: const Color(0xFF061F1A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _handleCreateVault,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Create New Vault 🏦',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ],

            // Tab 2: INTERNAL TRANSFER
            if (_currentTab == 2) ...[
              const Text(
                'TRANSFER FROM',
                style: TextStyle(
                  color: AppTheme.textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _transferSourceId.isNotEmpty
                    ? _transferSourceId
                    : (widget.accounts.isNotEmpty
                        ? widget.accounts.first.id
                        : null),
                dropdownColor: AppTheme.cardBg,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                ),
                items: widget.accounts.map((acc) {
                  return DropdownMenuItem(
                    value: acc.id,
                    child: Text(
                        '${acc.name} (${widget.currencySymbol}${acc.balance.toStringAsFixed(0)} available)'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _transferSourceId = val);
                  }
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'TRANSFER TO (DESTINATION)',
                style: TextStyle(
                  color: AppTheme.textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _transferDestId.isNotEmpty
                    ? _transferDestId
                    : (widget.accounts.length > 1
                        ? widget.accounts[1].id
                        : null),
                dropdownColor: AppTheme.cardBg,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                ),
                items: widget.accounts.map((acc) {
                  return DropdownMenuItem(
                    value: acc.id,
                    child: Text(
                        '${acc.name} (${widget.currencySymbol}${acc.balance.toStringAsFixed(0)})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _transferDestId = val);
                  }
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'TRANSFER AMOUNT',
                style: TextStyle(
                  color: AppTheme.textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _transferAmountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '${widget.currencySymbol} ',
                  prefixStyle: const TextStyle(
                      color: AppTheme.mint,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                  hintText: '500',
                  hintStyle: const TextStyle(color: AppTheme.textFaint),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.mint),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mint,
                    foregroundColor: const Color(0xFF061F1A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _handleTransfer,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Execute Internal Transfer ⇄',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ],

            if (_modalError != null) ...[
              const SizedBox(height: 12),
              Text(
                _modalError!,
                style: const TextStyle(color: AppTheme.rose, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _currentTab = index;
          _modalError = null;
        }),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isSelected
                      ? const Color(0xFF061F1A)
                      : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF061F1A)
                      : AppTheme.textMuted,
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
}
