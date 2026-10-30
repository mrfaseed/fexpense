import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fexpense/models/expense_item.dart';

void main() {
  group('ExpenseItem Unit Tests', () {
    test('Serialization and deserialization roundtrip preserves all fields', () {
      final now = DateTime(2026, 9, 8, 11, 30);
      final item = ExpenseItem(
        id: 'exp_123',
        title: 'Dinner at Italian Bistro',
        amount: 850.50,
        category: 'Food',
        icon: Icons.restaurant_outlined,
        date: now,
        accountId: 'acc_bank_1',
        accountName: 'HDFC Bank',
      );

      final json = item.toJson();
      final restored = ExpenseItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.amount, item.amount);
      expect(restored.category, item.category);
      expect(restored.date, item.date);
      expect(restored.accountId, item.accountId);
      expect(restored.accountName, item.accountName);
    });

    test('copyWith modifies targeted fields while preserving others', () {
      final item = ExpenseItem(
        id: 'exp_1',
        title: 'Coffee',
        amount: 120.0,
        category: 'Food',
        icon: Icons.coffee,
        date: DateTime.now(),
        accountId: 'acc_1',
        accountName: 'Cash',
      );

      final updated = item.copyWith(
        title: 'Specialty Coffee',
        amount: 150.0,
      );

      expect(updated.id, 'exp_1');
      expect(updated.title, 'Specialty Coffee');
      expect(updated.amount, 150.0);
      expect(updated.category, 'Food');
      expect(updated.accountId, 'acc_1');
    });

    test('iconFromCategory and colorFromCategory return valid distinct accents', () {
      expect(ExpenseItem.iconFromCategory('Food'), Icons.restaurant_outlined);
      expect(ExpenseItem.iconFromCategory('Transport'), Icons.directions_car_outlined);
      expect(ExpenseItem.iconFromCategory('Bills'), Icons.receipt_long_outlined);
      expect(ExpenseItem.iconFromCategory('UnknownCategory'), Icons.category_outlined);

      expect(ExpenseItem.colorFromCategory('Food'), isNotNull);
      expect(ExpenseItem.colorFromCategory('Health'), isNotNull);
    });
  });
}
