import 'package:flutter/material.dart';

class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final IconData icon;
  final DateTime date;
  final String? accountId;
  final String? accountName;

  const ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.icon,
    required this.date,
    this.accountId,
    this.accountName,
  });

  ExpenseItem copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    IconData? icon,
    DateTime? date,
    String? accountId,
    String? accountName,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'iconCode': icon.codePoint,
        'date': date.toIso8601String(),
        'accountId': accountId,
        'accountName': accountName,
      };

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Spend',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        category: json['category'] as String? ?? 'Other',
        icon: iconFromCategory(json['category'] as String? ?? 'Other'),
        date: json['date'] != null
            ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
            : DateTime.now(),
        accountId: json['accountId'] as String?,
        accountName: json['accountName'] as String?,
      );

  static IconData iconFromCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'bills':
        return Icons.receipt_long_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'investment':
        return Icons.trending_up_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  static Color colorFromCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFFF97316); // Orange
      case 'transport':
        return const Color(0xFF38BDF8); // Sky Blue
      case 'bills':
        return const Color(0xFFEF4444); // Red
      case 'shopping':
        return const Color(0xFFA855F7); // Purple
      case 'health':
        return const Color(0xFF10B981); // Emerald
      case 'entertainment':
        return const Color(0xFFEC4899); // Pink
      case 'education':
        return const Color(0xFF6366F1); // Indigo
      case 'investment':
        return const Color(0xFF14B8A6); // Teal
      default:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
