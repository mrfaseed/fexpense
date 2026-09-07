import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UserCredential?> signInWithGoogleDesktopOAuth({
  required FirebaseAuth auth,
  required String clientId,
  required String clientSecret,
}) async {
  // 1. Bind local loopback HTTP server on an ephemeral port
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final int port = server.port;
  final String redirectUri = 'http://127.0.0.1:$port';

  // 2. Build Google OAuth authorization URL
  final Uri authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'scope': 'openid email profile',
    'access_type': 'offline',
    'prompt': 'select_account',
  });

  // 3. Open user's default browser on Windows / Desktop
  final urlString = authUri.toString();
  if (defaultTargetPlatform == TargetPlatform.windows) {
    await Process.run('rundll32', ['url.dll,FileProtocolHandler', urlString]);
  } else if (defaultTargetPlatform == TargetPlatform.linux) {
    await Process.run('xdg-open', [urlString]);
  } else if (defaultTargetPlatform == TargetPlatform.macOS) {
    await Process.run('open', [urlString]);
  }

  // 4. Await authorization callback with a 2-minute timeout
  String? authCode;
  String? authError;

  try {
    final HttpRequest request = await server.first.timeout(
      const Duration(minutes: 2),
      onTimeout: () => throw TimeoutException(
          'Google sign-in timed out. Please try again.'),
    );

    final queryParams = request.uri.queryParameters;
    authCode = queryParams['code'];
    authError = queryParams['error'];

    request.response.headers.contentType = ContentType.html;

    if (authCode != null) {
      request.response.write('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>FExpense - Signed In</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #09090B;
      color: #FAFAFA;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
    }
    .card {
      background: #121215;
      border: 1px solid #27272A;
      border-radius: 16px;
      padding: 36px 32px;
      text-align: center;
      max-width: 400px;
      box-shadow: 0 16px 36px rgba(0,0,0,0.5);
    }
    .badge {
      display: inline-block;
      background: rgba(16, 185, 129, 0.15);
      color: #10B981;
      border: 1px solid rgba(16, 185, 129, 0.3);
      padding: 5px 12px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.8px;
      margin-bottom: 16px;
    }
    h1 {
      font-size: 20px;
      font-weight: 700;
      margin: 0 0 10px 0;
      letter-spacing: -0.4px;
    }
    p {
      font-size: 13.5px;
      color: #A1A1AA;
      margin: 0;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">&#10003; SIGN-IN SUCCESSFUL</div>
    <h1>Welcome to FExpense!</h1>
    <p>Your Google account has been verified. You can safely close this browser window and return to the app.</p>
  </div>
</body>
</html>
''');
    } else {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('''
<!DOCTYPE html>
<html>
<body style="background:#09090B;color:#F43F5E;font-family:sans-serif;padding:40px;text-align:center;">
  <h2>Sign-In Cancelled</h2>
  <p style="color:#A1A1AA;">${authError ?? 'No authorization code received'}. You can close this tab.</p>
</body>
</html>
''');
    }
    await request.response.close();
  } finally {
    await server.close(force: true);
  }

  if (authError != null) {
    throw Exception('Google Sign-In was cancelled or denied ($authError).');
  }
  if (authCode == null) {
    throw Exception('No authorization code was received from Google.');
  }

  // 5. Exchange auth code for ID token and Access token
  final httpClient = HttpClient();
  final tokenRequest =
      await httpClient.postUrl(Uri.parse('https://oauth2.googleapis.com/token'));
  tokenRequest.headers.contentType =
      ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');

  final Map<String, String> bodyFields = {
    'code': authCode,
    'client_id': clientId,
    'client_secret': clientSecret,
    'redirect_uri': redirectUri,
    'grant_type': 'authorization_code',
  };

  final String formBody = bodyFields.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');

  tokenRequest.write(formBody);
  final tokenResponse = await tokenRequest.close();
  final responseBody = await tokenResponse.transform(utf8.decoder).join();
  final json = jsonDecode(responseBody) as Map<String, dynamic>;

  if (tokenResponse.statusCode != HttpStatus.ok) {
    final err = json['error_description'] ??
        json['error'] ??
        'Token exchange failed with status ${tokenResponse.statusCode}';
    throw Exception('Google token exchange error: $err');
  }

  final String? idToken = json['id_token'] as String?;
  final String? accessToken = json['access_token'] as String?;

  if (idToken == null) {
    throw Exception('No id_token returned by Google token service.');
  }

  // 6. Sign in to Firebase Auth using GoogleAuthProvider.credential
  final AuthCredential credential = GoogleAuthProvider.credential(
    idToken: idToken,
    accessToken: accessToken,
  );

  final userCredential = await auth.signInWithCredential(credential);
  final user = userCredential.user;

  // 7. Update local cache with real user details
  final prefs = await SharedPreferences.getInstance();
  if (user?.displayName != null && user!.displayName!.isNotEmpty) {
    await prefs.setString('user_name', user.displayName!);
  }
  if (user?.email != null && user!.email!.isNotEmpty) {
    await prefs.setString('user_email', user.email!);
  }
  await prefs.setBool('is_desktop_authenticated', true);

  return userCredential;
}
