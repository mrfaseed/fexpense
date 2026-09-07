import 'package:flutter/material.dart';

class AccountVault {
  final String id;
  final String name; // e.g. "Primary Bank", "Cash in Hand", "HDFC", "Emergency Fund"
  final String type; // 'bank', 'cash', 'savings', 'wallet'
  final double balance;
  final int iconCode;
  final int colorValue;
  final DateTime createdAt;
  final bool isPrimary;

  AccountVault({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.iconCode,
    required this.colorValue,
    required this.createdAt,
    this.isPrimary = false,
  });

  IconData get icon => defaultIconForType(type);
  Color get color => Color(colorValue);

  AccountVault copyWith({
    String? id,
    String? name,
    String? type,
    double? balance,
    int? iconCode,
    int? colorValue,
    DateTime? createdAt,
    bool? isPrimary,
  }) {
    return AccountVault(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'balance': balance,
        'iconCode': iconCode,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'isPrimary': isPrimary,
      };

  factory AccountVault.fromJson(Map<String, dynamic> json) => AccountVault(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Vault',
        type: json['type'] as String? ?? 'bank',
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        iconCode: json['iconCode'] as int? ??
            Icons.account_balance_rounded.codePoint,
        colorValue: json['colorValue'] as int? ?? 0xFF00D09C,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        isPrimary: json['isPrimary'] as bool? ?? false,
      );

  static IconData defaultIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return Icons.payments_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'wallet':
        return Icons.flash_on_rounded;
      case 'bank':
      default:
        return Icons.account_balance_rounded;
    }
  }

  static Color defaultColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return const Color(0xFF34D399); // Emerald / Cash Green
      case 'savings':
        return const Color(0xFFFBBF24); // Amber / Savings
      case 'wallet':
        return const Color(0xFF38BDF8); // Cyan
      case 'bank':
      default:
        return const Color(0xFF818CF8); // Indigo / Bank
    }
  }
}
