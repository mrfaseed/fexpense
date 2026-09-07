# Changelog

All notable changes to the **FExpense** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
