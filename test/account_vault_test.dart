import 'package:flutter_test/flutter_test.dart';
import 'package:fexpense/models/account_vault.dart';

void main() {
  group('AccountVault Liquidity Engine Tests', () {
    test('Calculates consolidated balance across multiple bank accounts and cash in hand', () {
      final accounts = [
        AccountVault(
          id: 'acc_1',
          name: 'Primary Bank',
          type: 'bank',
          balance: 7000.0,
          iconCode: 0,
          colorValue: 0xFF818CF8,
          createdAt: DateTime.now(),
        ),
        AccountVault(
          id: 'acc_2',
          name: 'Cash in Hand',
          type: 'cash',
          balance: 400.0,
          iconCode: 0,
          colorValue: 0xFF34D399,
          createdAt: DateTime.now(),
        ),
        AccountVault(
          id: 'acc_3',
          name: 'Savings Vault',
          type: 'savings',
          balance: 2500.0,
          iconCode: 0,
          colorValue: 0xFFFBBF24,
          createdAt: DateTime.now(),
        ),
      ];

      final totalBalance = accounts.fold(0.0, (sum, acc) => sum + acc.balance);
      // 7000 + 400 + 2500 = 9900
      expect(totalBalance, 9900.0);

      // User specific scenario: Account 1 (7000) + Cash (400) = 7400
      final firstTwoTotal = accounts.take(2).fold(0.0, (sum, acc) => sum + acc.balance);
      expect(firstTwoTotal, 7400.0);
    });

    test('Internal transfer between vaults correctly updates balances', () {
      var bank = AccountVault(
        id: 'acc_bank',
        name: 'HDFC Bank',
        type: 'bank',
        balance: 7000.0,
        iconCode: 0,
        colorValue: 0xFF818CF8,
        createdAt: DateTime.now(),
      );

      var cash = AccountVault(
        id: 'acc_cash',
        name: 'Cash in Hand',
        type: 'cash',
        balance: 400.0,
        iconCode: 0,
        colorValue: 0xFF34D399,
        createdAt: DateTime.now(),
      );

      const transferAmount = 1000.0;
      expect(bank.balance >= transferAmount, isTrue);

      bank = bank.copyWith(balance: bank.balance - transferAmount);
      cash = cash.copyWith(balance: cash.balance + transferAmount);

      expect(bank.balance, 6000.0);
      expect(cash.balance, 1400.0);
      // Consolidated total remains invariant
      expect(bank.balance + cash.balance, 7400.0);
    });

    test('AccountVault serialization & deserialization round-trip', () {
      final now = DateTime.now();
      final vault = AccountVault(
        id: 'test_vault',
        name: 'Emergency Fund',
        type: 'savings',
        balance: 15420.50,
        iconCode: 12345,
        colorValue: 0xFFFBBF24,
        createdAt: now,
        isPrimary: true,
      );

      final json = vault.toJson();
      final restored = AccountVault.fromJson(json);

      expect(restored.id, vault.id);
      expect(restored.name, vault.name);
      expect(restored.type, vault.type);
      expect(restored.balance, vault.balance);
      expect(restored.colorValue, vault.colorValue);
      expect(restored.isPrimary, true);
    });

    test('Onboarding 2-Account setup (Bank 7000 [Primary] + Cash 400) correctly designates primary and consolidated total', () {
      final bank = AccountVault(
        id: 'acc_bank_1',
        name: 'HDFC Bank',
        type: 'bank',
        balance: 7000.0,
        iconCode: 0,
        colorValue: 0xFF818CF8,
        createdAt: DateTime.now(),
        isPrimary: true,
      );

      final cash = AccountVault(
        id: 'acc_cash_1',
        name: 'Cash in Hand',
        type: 'cash',
        balance: 400.0,
        iconCode: 0,
        colorValue: 0xFF34D399,
        createdAt: DateTime.now(),
        isPrimary: false,
      );

      final accounts = [bank, cash];
      final primary = accounts.firstWhere((a) => a.isPrimary);
      expect(primary.name, 'HDFC Bank');
      expect(primary.balance, 7000.0);

      final total = accounts.fold(0.0, (sum, a) => sum + a.balance);
      expect(total, 7400.0);
    });
  });
}
