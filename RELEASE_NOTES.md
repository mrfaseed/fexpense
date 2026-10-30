# FExpense v2.0.0 — Major Architecture & Performance Release 🚀

Welcome to **FExpense v2.0.0**! This release brings significant architectural modularization, full interactive multi-tab navigation, deep spending intelligence, memory-leak-free modals, live transaction search, and atomic Cloud Firestore batch writes.

---

## 🌟 What's New in v2.0.0

### 🧭 Interactive Multi-Tab Navigation
- **Screen Switching**: Clicking **Analytics** or **Categories** in the desktop sidebar or mobile bottom bar now seamlessly switches between dedicated views.
- **State Preservation**: Backed by Flutter's `IndexedStack` to ensure scroll positions and active inputs are never lost when jumping between tabs.

### 📊 Deep Spending Intelligence (Analytics Tab)
- **Period Breakdown**: Filter outflow across *All Time*, *This Month*, and *This Week*.
- **Category Proportions**: Dynamic percentage indicators with custom color badges for each category.
- **Vault Utilization**: Analyze which liquidity vaults you spend from the most (Bank vs Cash vs Savings).
- **Largest Spends Ranking**: Instant audit view of your top 5 individual expenditures.

### 🗂️ Expense Categories Explorer (Categories Tab)
- **Visual Category Grid**: Comprehensive overview of all spending categories with aggregated totals and transaction counters.
- **Draggable Inspection Sheet**: Tap any category to inspect all historical transactions recorded under it.

### ⚡ Live Search & Filtering
- **Interactive Search Bar**: Real-time keyword filtering across notes, categories, and account names in the Home dashboard.
- **Filter Reset**: Quick clear button to instantly restore the full transaction feed.

### 🛡️ Atomic Cloud Firestore Transactions
- **Data Integrity Guarantee**: Spend deductions, refund restorations, and vault-to-vault transfers are committed using atomic Firestore `WriteBatch` operations, eliminating state desynchronization.
- **Safe Deletions**: Guarded against null and race condition crashes during rapid transaction deletions.

### 🧹 Clean Architecture & Zero-Leak Modals
- **Modularization**: Reduced monolithic screen from **3,090 lines** down to **~635 lines** with dedicated tabs and modals.
- **Memory Safety**: Dedicated `AddSpendModal` and `VaultActionModal` widgets guarantee strict `TextEditingController` disposal lifecycles.
- **Separation of Concerns**: Extracted `ExpenseItem` out of UI code into `lib/models/expense_item.dart`, removing circular imports.

---

## 🚀 Getting Started

```bash
# Clone the repository
git clone https://github.com/mrfaseed/fexpense.git
cd fexpense

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run application
flutter run -d windows
# or
flutter run -d android
# or
flutter run -d chrome
```

---

## 📋 Full Changelog
See [CHANGELOG.md](CHANGELOG.md) for the complete version history.

---

**Author**: [@mrfaseed](https://github.com/mrfaseed)  
**License**: MIT
