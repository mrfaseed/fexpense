import 'package:firebase_auth/firebase_auth.dart';

Future<UserCredential?> signInWithGoogleDesktopOAuth({
  required FirebaseAuth auth,
  required String clientId,
  required String clientSecret,
}) async {
  throw UnsupportedError(
      'Desktop OAuth loopback is only supported on native desktop platforms.');
}
