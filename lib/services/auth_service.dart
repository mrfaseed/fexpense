import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'desktop_oauth_stub.dart'
    if (dart.library.io) 'desktop_oauth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '613588113694-k50oh0mpfen9tftmtgm6suj0qc20jk8h.apps.googleusercontent.com',
  );
  static const String _googleClientSecret = String.fromEnvironment(
    'GOOGLE_CLIENT_SECRET',
    defaultValue: '',
  );

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth?.authStateChanges() ?? const Stream.empty();
    } catch (_) {
      return const Stream.empty();
    }
  }

  User? get currentUser {
    try {
      return _auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  String get currentUid => currentUser?.uid ?? 'desktop_faseed';

  String get currentDisplayName =>
      currentUser?.displayName ?? 'Faseed';

  String get currentEmail =>
      currentUser?.email ?? 'faseed@google.com';

  String? get currentPhotoUrl => currentUser?.photoURL;

  Future<bool> isSignedIn() async {
    if (currentUser != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_desktop_authenticated') ?? false;
  }

  /// Sign in with Google (supports Web, Android, iOS, and seamless Windows Desktop mode)
  Future<UserCredential?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      debugPrint('Firebase is not initialized.');
      return null;
    }

    try {
      if (kIsWeb) {
        // Web: Real Firebase Google Popup
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        return await auth.signInWithPopup(googleProvider);
      } else if (isDesktop) {
        if (_googleClientSecret.isEmpty) {
          debugPrint(
            '⚠️ [AuthService] Notice: GOOGLE_CLIENT_SECRET is empty. '
            'Pass --dart-define=GOOGLE_CLIENT_SECRET=YOUR_SECRET to authenticate on desktop.',
          );
        }
        // Windows/Linux desktop:
        // Launch native Google OAuth 2.0 loopback server in default browser
        return await signInWithGoogleDesktopOAuth(
          auth: auth,
          clientId: _googleClientId,
          clientSecret: _googleClientSecret,
        );
      } else {
        // Mobile (Android, iOS) using GoogleSignIn 7.x
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        try {
          await GoogleSignIn.instance.initialize();
          final GoogleSignInAccount account =
              await GoogleSignIn.instance.authenticate();
          final String? idToken = account.authentication.idToken;

          String? accessToken;
          try {
            final clientAuth = await account.authorizationClient
                .authorizationForScopes(['email', 'profile']);
            accessToken = clientAuth?.accessToken;
          } catch (_) {}

          final AuthCredential credential = GoogleAuthProvider.credential(
            idToken: idToken,
            accessToken: accessToken,
          );
          return await auth.signInWithCredential(credential);
        } catch (e) {
          debugPrint('Native Google Sign-In error, falling back: $e');
          return await auth.signInWithProvider(googleProvider);
        }
      }
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  /// Sign out securely from Firebase and Google
  Future<void> signOut() async {
    try {
      if (!kIsWeb && !isDesktop) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      try {
        await _auth?.signOut();
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_desktop_authenticated');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('is_onboarded');
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }
}
