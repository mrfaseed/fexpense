# Changelog

All notable changes to the **FExpense** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] - 2026-09-08

### Added
- **Interactive Multi-Tab Navigation**: Fully implemented screen switching between `HomeTab`, `AnalyticsTab`, and `CategoriesTab` using an `IndexedStack` preserving scroll and interaction states across navigation events.
- **Deep Spending Intelligence (Analytics Tab)**:
  - Total outflow, average spend per transaction, and transaction frequency.
  - Interactive period filtering: All Time, This Month, and This Week.
  - Category spending breakdown with percentage gauges and distinct category color accents.
  - Vault utilization tracking (e.g. Bank vs Cash in Hand vs Savings outflow).
  - Largest individual transactions highlight list for fast expenditure audits.
- **Expense Categories Explorer (Categories Tab)**:
  - Grid view of all standard and custom categories with total spend, transaction counts, and visual progress.
  - Tap-to-inspect bottom sheet detailing all individual expenses logged under each category.
- **Live Search & Filter Engine**: Real-time keyword filtering across notes, categories, and account names with instant clear controls in the home dashboard.
- **Atomic Cloud Firestore Transactions**:
  - `addExpenseWithBalance`: Simultaneously writes the spend and deducts from the specified account vault in an atomic Firestore batch.
  - `deleteExpenseWithRefund`: Simultaneously removes the spend and refunds balance back to the vault in an atomic Firestore batch.
  - `transferVaultFunds`: Transfers liquidity between vaults atomically in a single batch commit.
- **Zero-Memory-Leak Modals**: Dedicated `AddSpendModal` and `VaultActionModal` widgets with strict `TextEditingController` disposal lifecycles.
- **Brand Theme System Consolidation**: Unified Dark Mint & Forest palette tokens centralized in `AppTheme`.
- **Extended Test Suite**:
  - `test/expense_item_test.dart`: Model serialization, copyWith, and category icon/color mappings.
  - `test/analytics_engine_test.dart`: Outflow aggregation, category totals, and vault utilization calculations.

### Fixed
- **Navigation Non-Responsiveness**: Fixed critical issue where tapping *Analytics* or *Categories* in the desktop sidebar or mobile bottom bar failed to switch screens.
- **Search Button Dead-End**: Fixed non-functional search icon in top header bar with an expandable search input.
- **Controller Memory Leaks**: Fixed multiple un-disposed text editing controllers allocated inside modal builders.
- **Delete Crash Vulnerability**: Fixed unhandled `StateError: No element` on rapid double-tap or concurrent deletion of an expense item.
- **Missing Validation Feedback**: Added explicit validation feedback and warnings when spend amounts exceed vault balances or inputs are invalid.
- **Silent Fallback Overwrite**: Sanitized fallback guest identifiers in `AuthService` to prevent unintentional account collisions.

### Changed
- **Architectural Modularization**: Refactored monolithic 3,090-line screen into focused, maintainable components (`lib/models/expense_item.dart`, `tabs/`, `widgets/modals/`).
- **Separation of Concerns**: Extracted `ExpenseItem` out of UI layer to eliminate circular service imports.

---

## [1.0.0] - 2026-09-07

### Added
- **Multi-Vault Liquidity Engine**: Create and manage multiple accounts (Bank Accounts, Cash in Hand, Savings Vaults) with dynamic consolidated balance calculation.
- **Internal Vault Transfers**: Instant liquidity transfers between vaults with atomic balance preservation.
- **Cloud Firestore Synchronization**: Real-time multi-device database syncing for transactions, accounts, and profiles.
- **Cross-Platform Authentication**:
  - Native Google Sign-In for Android and iOS.
  - Interactive browser loopback OAuth 2.0 flow for Windows and Linux desktop.
  - Web Google popup sign-in support.
- **Expense Categorization & Analytics**:
  - Dynamic categorization (Food, Transport, Bills, Shopping, Health, and custom).
  - Spending breakdowns, budget progress tracking, and interactive visualizations.
- **Desktop Keyboard Shortcuts**:
  - `Ctrl + Shift + R` or `Cmd + Shift + R` / `F12`: Reset and quick diagnostics modal.
- **Windows Packaging**:
  - Inno Setup compiler build automation script (`build_installer.ps1`).
- **Comprehensive Test Suite**:
  - AccountVault liquidity calculation unit tests.
  - Serialization & deserialization round-trip tests.
  - Widget and loader rendering tests.
- **Community Governance & CI**:
  - GitHub Actions CI workflow for static analysis and automated testing.
  - Issue templates, pull request template, and contribution guidelines.
