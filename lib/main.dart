import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/app_reset_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the configured project fexpense-72e92
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp warning/notice: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const FExpenseApp());
}

class FExpenseApp extends StatelessWidget {
  const FExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FExpense',
      navigatorKey: AppResetService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      builder: (context, child) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyR,
                control: true, shift: true): () {
              final ctx =
                  AppResetService.navigatorKey.currentContext ?? context;
              AppResetService.confirmAndReset(ctx);
            },
            const SingleActivator(LogicalKeyboardKey.keyR,
                meta: true, shift: true): () {
              final ctx =
                  AppResetService.navigatorKey.currentContext ?? context;
              AppResetService.confirmAndReset(ctx);
            },
            const SingleActivator(LogicalKeyboardKey.f12): () {
              final ctx =
                  AppResetService.navigatorKey.currentContext ?? context;
              AppResetService.confirmAndReset(ctx);
            },
            const SingleActivator(LogicalKeyboardKey.delete,
                control: true, shift: true): () {
              final ctx =
                  AppResetService.navigatorKey.currentContext ?? context;
              AppResetService.confirmAndReset(ctx);
            },
          },
          child: Focus(
            autofocus: true,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}