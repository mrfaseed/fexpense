import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fexpense/main.dart';
import 'package:fexpense/widgets/minimal_loader.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MinimalLoader renders cleanly with customizable attributes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MinimalLoader(
            size: 32,
            strokeWidth: 3.0,
            color: Colors.white,
          ),
        ),
      ),
    );

    expect(find.byType(MinimalLoader), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets(
      'FExpenseApp loads pure minimal loader (no text) and transitions to Google Auth screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FExpenseApp());

    // Verify only the minimal loader is present on splash, and no text
    expect(find.byType(MinimalLoader), findsOneWidget);
    expect(find.byType(Text), findsNothing);

    // Advance timer past splash duration (1400ms) and allow navigation
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Google Auth screen is shown with premium Continue with Google button
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Secure Access'), findsOneWidget);
    expect(find.textContaining('Sign in with your Google account'),
        findsOneWidget);
  });
}
