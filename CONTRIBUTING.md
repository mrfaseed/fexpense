# Contributing to FExpense

Thank you for your interest in contributing to **FExpense**! We welcome contributions from developers of all skill levels. Whether you are fixing a bug, adding a new feature, improving documentation, or optimizing performance, your help makes this project better.

Please review the guidelines below to ensure a smooth contribution process.

---

## Code of Conduct

All contributors are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Please treat others with empathy and respect.

---

## How Can You Contribute?

1. **Reporting Bugs**: Check the [Issues](https://github.com/mrfaseed/fexpense/issues) tab first. If not reported, submit an issue using the Bug Report template with detailed reproduction steps.
2. **Suggesting Enhancements**: Open an issue using the Feature Request template to discuss new ideas before implementing them.
3. **Code Contributions**: Submit pull requests fixing open issues or adding agreed-upon features.
4. **Improving Documentation**: Fix typos, clarify setup guides, or add code examples.

---

## Development Setup

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.13.2` or later)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio / VS Code with Flutter and Dart extensions
- (For Windows release installer): [Inno Setup 6](https://jrsoftware.org/isinfo.php)

### Getting the Code

1. **Fork the repository** on GitHub:
   Navigate to [github.com/mrfaseed/fexpense](https://github.com/mrfaseed/fexpense) and click **Fork**.

2. **Clone your fork locally**:
   ```bash
   git clone https://github.com/<your-username>/fexpense.git
   cd fexpense
   ```

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Configure Firebase**:
   Configure your own Firebase project using the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

5. **Run the application**:
   ```bash
   # Android
   flutter run -d android

   # Windows Desktop (with optional OAuth secret)
   flutter run -d windows --dart-define=GOOGLE_CLIENT_SECRET=YOUR_SECRET

   # Chrome Web
   flutter run -d chrome
   ```

---

## Development Workflow & Guidelines

### Branching Strategy
- Create a topic branch from `main`:
  ```bash
  git checkout -b feature/your-feature-name
  # or
  git checkout -b fix/issue-description
  ```

### Code Style & Quality
- Follow standard [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines.
- Keep UI components decoupled and reusable.
- Verify there are no lint warnings before committing:
  ```bash
  flutter analyze
  ```

### Testing
- Always run the test suite and ensure all tests pass:
  ```bash
  flutter test
  ```
- If adding new features, add corresponding unit or widget tests in the `test/` directory.

### Commit Messages
We follow the [Conventional Commits](https://www.conventionalcommits.org/) format:
- `feat: add export to CSV functionality`
- `fix: resolve balance calculation issue on zero-balance vault`
- `docs: update setup instructions in README`
- `test: add unit test for multi-currency conversion`
- `refactor: clean up firestore service error handlers`

---

## Submitting a Pull Request

1. Push your changes to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
2. Open a Pull Request against the `main` branch of `mrfaseed/fexpense`.
3. Complete the provided Pull Request template checklist.
4. Ensure the GitHub Actions CI workflow passes.
5. Participate in code review feedback. Once approved, your PR will be merged!
