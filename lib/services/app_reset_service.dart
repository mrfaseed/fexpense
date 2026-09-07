import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/splash_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/minimal_loader.dart';

class AppResetService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Displays the confirmation dialog to clear all data and start fresh
  static void confirmAndReset(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _ResetConfirmationDialog(),
    );
  }

  /// Performs the full reset of cache, files, auth sessions, and Firestore records
  static Future<void> performFullReset(BuildContext context) async {
    // Show non-dismissible loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppTheme.surfaceElevated,
          elevation: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Row(
              children: [
                MinimalLoader(
                  size: 26,
                  strokeWidth: 2.4,
                  color: AppTheme.rose,
                  showTrack: true,
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Clearing all cache & resetting app...',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 1. Wipe remote Firestore data for current user
      final uid = AuthService().currentUid;
      try {
        await FirestoreService().resetUserData(uid);
      } catch (e) {
        debugPrint('Firestore resetUserData notice: $e');
      }

      // 2. Clear local SharedPreferences (tokens, onboarding flags, budget, cache)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (e) {
        debugPrint('SharedPreferences clear notice: $e');
      }

      // 3. Clear Firestore local offline cache
      try {
        await FirebaseFirestore.instance.clearPersistence();
      } catch (e) {
        debugPrint('FirebaseFirestore clearPersistence notice: $e');
      }

      // 4. Sign out from Firebase Auth, Google Sign In, & desktop session
      try {
        await AuthService().signOut();
      } catch (e) {
        debugPrint('AuthService signOut notice: $e');
      }
    } catch (e) {
      debugPrint('Error during performFullReset: $e');
    }

    // Brief delay to allow native states to settle
    await Future.delayed(const Duration(milliseconds: 600));

    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );
    }
  }
}

class _ResetConfirmationDialog extends StatelessWidget {
  const _ResetConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
      contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.rose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.rose.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.delete_forever_rounded,
              color: AppTheme.rose,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clear All & Start Fresh',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'FULL RESET • FACTORY CLEAN',
                  style: TextStyle(
                    color: AppTheme.rose,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'This action completely wipes the app and returns it to a brand-new installation:',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          _buildBulletPoint('All login sessions (Google & Firebase) signed out'),
          _buildBulletPoint('All local cache, balance & preferences cleared'),
          _buildBulletPoint('All Cloud Firestore transactions & user data deleted'),
          _buildBulletPoint('Restarts at the first clean login screen'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.keyboard_outlined,
                    size: 16, color: AppTheme.textTertiary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Developer shortcut: Press Ctrl+Shift+R or F12 anywhere on desktop.',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.rose,
            foregroundColor: Colors.white,
            minimumSize: const Size(130, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            AppResetService.performFullReset(context);
          },
          child: const Text(
            'Delete & Start Fresh',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 8),
            child: Icon(
              Icons.circle,
              size: 5,
              color: AppTheme.rose,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
