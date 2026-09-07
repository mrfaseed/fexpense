<div align="center">

# 💎 FExpense

**A Modern, Minimalist & Cross-Platform Expense & Liquidity Management Application**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20iOS%20%7C%20Web%20%7C%20macOS%20%7C%20Linux-brightgreen)](https://flutter.dev)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Code Style](https://img.shields.io/badge/Code%20Style-Flutter%20Lints-blue)](analysis_options.yaml)

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#screenshots--ui-showcase">Screenshots</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#firebase-setup">Firebase Setup</a> •
  <a href="#building-for-release">Building</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

</div>

---

## 🌟 Overview

**FExpense** is a fast, beautifully designed, cross-platform personal finance and liquidity tracking application built with **Flutter**, **Firebase Auth**, and **Cloud Firestore**. 

Unlike standard expense apps that only track isolated expenses, FExpense features a **Multi-Vault Liquidity Engine** that models your actual financial state across bank accounts, cash in hand, and savings vaults—complete with consolidated balance tracking and atomic vault-to-vault transfers.

Designed with a sleek **Dark Mint & Forest** theme, fluid micro-animations, keyboard-first desktop shortcuts, and real-time cloud synchronization, FExpense delivers an exceptional experience across mobile, desktop, and web.

---

## ✨ Key Features

- 🏦 **Multi-Vault Liquidity Engine**:
  - Track multiple accounts simultaneously (Primary Bank, Secondary Banks, Cash in Hand, Emergency Funds, Savings).
  - Consolidated total balance calculations with real-time recalculation on every transaction.
  - Dedicated primary vault indicators and customizable vault styling.

- 🔄 **Internal Vault-to-Vault Transfers**:
  - Transfer funds directly between vaults (e.g. ATM withdrawal from Bank to Cash, or Bank to Savings) without altering net net-worth.

- ☁️ **Real-Time Cloud Synchronization**:
  - Backed by **Google Cloud Firestore** for seamless multi-device persistence and live updates.
  - Offline-first architecture with local cache fallback via `shared_preferences`.

- 🔐 **Cross-Platform Authentication**:
  - **Android & iOS**: Native Google Sign-In SDK integration.
  - **Windows & Linux Desktop**: Automated loopback HTTP server (`http://127.0.0.1:<port>`) with system browser OAuth 2.0 authentication.
  - **Web**: Firebase Google Auth popup integration.

- 📊 **Intelligent Expense Categorization & Analytics**:
  - Preset and custom categories (Food, Transport, Bills, Shopping, Health, and more).
  - Category spending breakdown with visual progress tracking against defined monthly budgets.

- ⚡ **Desktop Power-User Shortcuts**:
  - `Ctrl + Shift + R` / `Cmd + Shift + R`: Quick diagnostics and application reset modal.
  - `F12` / `Ctrl + Shift + Del`: System cache flush shortcuts.

- 📦 **Windows Release Automation**:
  - Automated PowerShell script (`build_installer.ps1`) bundling release binaries into a standalone **Inno Setup** Windows installer (`FExpense_Setup.exe`).

---

## 📸 Screenshots & UI Showcase

| Dashboard & Vaults | Expense Categorization | Google Auth & Desktop |
|:---:|:---:|:---:|
| Multi-account consolidated balance & quick actions | Interactive category breakdown & budget limits | Minimalist secure Google authentication |

---

## 🛠️ Tech Stack & Architecture

- **UI Framework**: [Flutter](https://flutter.dev) (SDK `^3.13.2`)
- **Language**: [Dart](https://dart.dev) (SDK `^3.13.2`)
- **Cloud Backend**: [Firebase](https://firebase.google.com)
  - `firebase_core`: Platform initialization
  - `firebase_auth`: User authentication
  - `cloud_firestore`: Real-time NoSQL cloud database
  - `google_sign_in`: Mobile Google Identity Services
- **Local Persistence**: `shared_preferences`
- **Desktop Packaging**: Inno Setup 6 compiler script

### Directory Structure
```
fexpense/
├── .github/
│   ├── workflows/ci.yml           # Automated CI pipeline (lints & tests)
│   ├── ISSUE_TEMPLATE/            # Bug report & feature request templates
│   └── pull_request_template.md   # PR guidelines checklist
├── android/                       # Android native project files
├── assets/
│   └── icon/                      # High-resolution application launcher icons
├── ios/                           # iOS native project files
├── lib/
│   ├── models/                    # Data models (AccountVault, ExpenseItem)
│   ├── screens/                   # Splash, Auth, Onboarding & Expense Tracker
│   ├── services/                  # AuthService, FirestoreService, AppResetService
│   ├── theme/                     # AppTheme styling tokens & dark palette
│   ├── widgets/                   # MinimalLoader, BorderBeamCard, AiGradient
│   ├── firebase_options.dart      # Firebase client configuration
│   └── main.dart                  # Application entry point
├── test/                          # Unit and widget test suite
├── windows/                       # Windows native C++ runner & Inno Setup scripts
├── build_installer.ps1            # Windows installer automated compiler script
├── CONTRIBUTING.md                # Contributing guidelines
├── CODE_OF_CONDUCT.md             # Contributor Covenant v2.1
├── LICENSE                        # MIT License
└── pubspec.yaml                   # Dependencies & metadata
```

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed on your machine:
- [Git](https://git-scm.com/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13.2 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- For Android: [Android Studio](https://developer.android.com/studio) with Android SDK
- For Windows Desktop: Visual Studio 2022 (with Desktop development with C++)
- For Windows Installer generation: [Inno Setup 6](https://jrsoftware.org/isinfo.php)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/mrfaseed/fexpense.git
   cd fexpense
   ```

2. **Fetch Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Flutter setup**:
   ```bash
   flutter doctor
   ```

---

## 🔧 Firebase Setup

To connect FExpense to your own Firebase project:

1. Install and log in to the [Firebase CLI](https://firebase.google.com/docs/cli):
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

2. Activate and run the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Select your Firebase project and enable platforms (**Android, iOS, Web, macOS, Windows**). This automatically generates `lib/firebase_options.dart`.

3. In your **Firebase Console**:
   - Enable **Authentication** -> **Sign-in method** -> **Google**.
   - Create a **Cloud Firestore** database (in production or test mode).
   - Recommended Firestore security rule snippet:
     ```javascript
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /users/{userId}/{document=**} {
           allow read, write: if request.auth != null && request.auth.uid == userId;
         }
       }
     }
     ```

### Desktop Google OAuth Configuration (Optional)

For Windows/Linux desktop Google Sign-In, provide your OAuth credentials at build time using `--dart-define`:
```bash
flutter run -d windows --dart-define=GOOGLE_CLIENT_SECRET=your_google_client_secret
```

---

## 💻 Running the Application

Run FExpense on your preferred platform:

```bash
# Android emulator or connected device
flutter run -d android

# Windows Desktop
flutter run -d windows

# Google Chrome (Web)
flutter run -d chrome

# iOS Simulator (macOS only)
flutter run -d ios

# macOS Desktop (macOS only)
flutter run -d macos

# Linux Desktop
flutter run -d linux
```

---

## 📦 Building for Release

### Android
```bash
# Release APK
flutter build apk --release

# App Bundle for Google Play
flutter build appbundle --release
```

### Windows Standalone & Installer
To compile the Flutter release binaries and package the installer in one step:
```powershell
powershell -ExecutionPolicy Bypass -File .\build_installer.ps1
```
The output installer will be generated at:
`build\installer\FExpense_Setup.exe`

### Web
```bash
flutter build web --release
```

---

## 🧪 Testing & Code Quality

Run the test suite:
```bash
flutter test
```

Run static analysis:
```bash
flutter analyze
```

---

## 🤝 Contributing

Contributions make the open-source community an amazing place to learn, inspire, and create! Any contributions you make are **greatly appreciated**.

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to get started, our code style guide, and the pull request process.

Please review our [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

---

## 🔒 Security

For security vulnerabilities and responsible disclosure guidelines, please refer to [SECURITY.md](SECURITY.md).

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Mohamed Faseed**
- GitHub: [@mrfaseed](https://github.com/mrfaseed)
- Project Repository: [github.com/mrfaseed/fexpense](https://github.com/mrfaseed/fexpense)

---

<div align="center">
  <sub>Built with ❤️ using Flutter and Firebase</sub>
</div>
