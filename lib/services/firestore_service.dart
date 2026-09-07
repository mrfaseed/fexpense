import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/account_vault.dart';
import '../screens/expense_tracker_screen.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _expensesCollection(String uid) =>
      _userDoc(uid).collection('expenses');

  CollectionReference<Map<String, dynamic>> _accountsCollection(String uid) =>
      _userDoc(uid).collection('accounts');

  /// Fetch user profile & starting balance
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _userDoc(uid).get();
      return doc.data();
    } catch (e) {
      debugPrint('Firestore getUserProfile error: $e');
      return null;
    }
  }

  /// Save or update user profile and initial budget
  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String email,
    String? photoUrl,
    required String currencySymbol,
    required String walletType,
    required double totalBudget,
  }) async {
    try {
      await _userDoc(uid).set({
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'currencySymbol': currencySymbol,
        'walletType': walletType,
        'totalBudget': totalBudget,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveUserProfile error: $e');
      rethrow;
    }
  }

  /// Update just the total budget
  Future<void> updateTotalBudget(String uid, double newBudget) async {
    try {
      await _userDoc(uid).update({
        'totalBudget': newBudget,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore updateTotalBudget error: $e');
    }
  }

  // ---------------------------------------------------------
  // MULTI-ACCOUNT & VAULT OPERATIONS
  // ---------------------------------------------------------

  /// Stream of all user accounts & vaults
  Stream<List<AccountVault>> streamAccounts(String uid) {
    return _accountsCollection(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        DateTime dt = DateTime.now();
        if (data['createdAt'] is Timestamp) {
          dt = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is String) {
          dt = DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
        }
        final type = data['type'] as String? ?? 'bank';
        return AccountVault(
          id: doc.id,
          name: data['name'] as String? ?? 'Vault',
          type: type,
          balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
          iconCode: data['iconCode'] as int? ??
              AccountVault.defaultIconForType(type).codePoint,
          colorValue: data['colorValue'] as int? ??
              AccountVault.defaultColorForType(type).toARGB32(),
          createdAt: dt,
          isPrimary: data['isPrimary'] as bool? ?? false,
        );
      }).toList();
    });
  }

  /// Save or update an account/vault
  Future<void> saveAccount(String uid, AccountVault account) async {
    try {
      await _accountsCollection(uid).doc(account.id).set({
        'name': account.name,
        'type': account.type,
        'balance': account.balance,
        'iconCode': account.iconCode,
        'colorValue': account.colorValue,
        'isPrimary': account.isPrimary,
        'createdAt': Timestamp.fromDate(account.createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveAccount error: $e');
      rethrow;
    }
  }

  /// Update account balance directly
  Future<void> updateAccountBalance(
      String uid, String accountId, double newBalance) async {
    try {
      await _accountsCollection(uid).doc(accountId).update({
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore updateAccountBalance error: $e');
    }
  }

  /// Delete an account/vault
  Future<void> deleteAccount(String uid, String accountId) async {
    try {
      await _accountsCollection(uid).doc(accountId).delete();
    } catch (e) {
      debugPrint('Firestore deleteAccount error: $e');
    }
  }

  // ---------------------------------------------------------
  // EXPENSES OPERATIONS
  // ---------------------------------------------------------

  /// Stream of user expenses ordered by date descending
  Stream<List<ExpenseItem>> streamExpenses(String uid) {
    return _expensesCollection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        DateTime dt = DateTime.now();
        if (data['date'] is Timestamp) {
          dt = (data['date'] as Timestamp).toDate();
        } else if (data['date'] is String) {
          dt = DateTime.tryParse(data['date'] as String) ?? DateTime.now();
        }
        return ExpenseItem(
          id: doc.id,
          title: data['title'] as String? ?? 'Spend',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          category: data['category'] as String? ?? 'Other',
          icon: ExpenseItem.iconFromCategory(
              data['category'] as String? ?? 'Other'),
          date: dt,
          accountId: data['accountId'] as String?,
          accountName: data['accountName'] as String?,
        );
      }).toList();
    });
  }

  /// Add spend
  Future<void> addExpense(String uid, ExpenseItem item) async {
    try {
      await _expensesCollection(uid).doc(item.id).set({
        'title': item.title,
        'amount': item.amount,
        'category': item.category,
        'date': Timestamp.fromDate(item.date),
        'accountId': item.accountId,
        'accountName': item.accountName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore addExpense error: $e');
      rethrow;
    }
  }

  /// Delete spend (refund)
  Future<void> deleteExpense(String uid, String expenseId) async {
    try {
      await _expensesCollection(uid).doc(expenseId).delete();
    } catch (e) {
      debugPrint('Firestore deleteExpense error: $e');
    }
  }

  /// Reset all data for this user
  Future<void> resetUserData(String uid) async {
    try {
      final batch = _db.batch();
      final expenses = await _expensesCollection(uid).get();
      for (final doc in expenses.docs) {
        batch.delete(doc.reference);
      }
      final accounts = await _accountsCollection(uid).get();
      for (final doc in accounts.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_userDoc(uid));
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore resetUserData error: $e');
    }
  }
}
