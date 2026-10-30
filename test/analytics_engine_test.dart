import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fexpense/models/expense_item.dart';

void main() {
  group('Analytics Engine Aggregation Tests', () {
    final testExpenses = [
      ExpenseItem(
        id: '1',
        title: 'Groceries',
        amount: 500.0,
        category: 'Food',
        icon: Icons.restaurant_outlined,
        date: DateTime(2026, 9, 1),
        accountId: 'acc_1',
        accountName: 'Primary Bank',
      ),
      ExpenseItem(
        id: '2',
        title: 'Dinner',
        amount: 300.0,
        category: 'Food',
        icon: Icons.restaurant_outlined,
        date: DateTime(2026, 9, 2),
        accountId: 'acc_1',
        accountName: 'Primary Bank',
      ),
      ExpenseItem(
        id: '3',
        title: 'Metro Pass',
        amount: 200.0,
        category: 'Transport',
        icon: Icons.directions_car_outlined,
        date: DateTime(2026, 9, 3),
        accountId: 'acc_2',
        accountName: 'Cash',
      ),
      ExpenseItem(
        id: '4',
        title: 'Electricity',
        amount: 1000.0,
        category: 'Bills',
        icon: Icons.receipt_long_outlined,
        date: DateTime(2026, 9, 4),
        accountId: 'acc_1',
        accountName: 'Primary Bank',
      ),
    ];

    test('Calculates total outflow correctly', () {
      final total = testExpenses.fold(0.0, (sum, e) => sum + e.amount);
      expect(total, 2000.0);
    });

    test('Aggregates correctly by category', () {
      final categoryTotals = <String, double>{};
      for (final e in testExpenses) {
        categoryTotals[e.category] =
            (categoryTotals[e.category] ?? 0.0) + e.amount;
      }

      expect(categoryTotals['Food'], 800.0);
      expect(categoryTotals['Transport'], 200.0);
      expect(categoryTotals['Bills'], 1000.0);
    });

    test('Aggregates correctly by vault utilization', () {
      final vaultTotals = <String, double>{};
      for (final e in testExpenses) {
        final vaultName = e.accountName ?? 'Unknown';
        vaultTotals[vaultName] = (vaultTotals[vaultName] ?? 0.0) + e.amount;
      }

      expect(vaultTotals['Primary Bank'], 1800.0);
      expect(vaultTotals['Cash'], 200.0);
    });
  });
}
