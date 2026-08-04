import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/api_config.dart';

/// Result of a Google interactive sign-in.
enum GoogleSignInOutcome { success, cancelled, failed }

class GoogleSignInResult {
  final GoogleSignInOutcome outcome;

  /// The Google ID token (a JWT) to hand to our backend for verification. Only
  /// present when [outcome] is [GoogleSignInOutcome.success].
  final String? idToken;

  /// A human-readable reason when [outcome] is [GoogleSignInOutcome.failed].
  final String? errorMessage;

  const GoogleSignInResult._(this.outcome, {this.idToken, this.errorMessage});

  const GoogleSignInResult.success(String token)
    : this._(GoogleSignInOutcome.success, idToken: token);
  const GoogleSignInResult.cancelled() : this._(GoogleSignInOutcome.cancelled);
  const GoogleSignInResult.failed(String message)
    : this._(GoogleSignInOutcome.failed, errorMessage: message);
}

/// Thin wrapper around the google_sign_in plugin. Runs the account picker and
/// returns the ID token, which the caller sends to `POST /api/auth/google`.
///
/// `serverClientId` is our Web OAuth client id — it makes Google mint the ID
/// token for our backend (its `aud` claim equals this id), which the server
/// then verifies. On Android, Google also matches the app's package name +
/// signing SHA-1 against an Android OAuth client in the same Cloud project;
/// that client is configured in Google Cloud and is not referenced here.
class GoogleSignInService {
  GoogleSignInService({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            serverClientId: ApiConfig.googleWebClientId,
            scopes: const <String>['email'],
          );

  final GoogleSignIn _googleSignIn;

  Future<GoogleSignInResult> signIn() async {
    if (!ApiConfig.isGoogleSignInEnabled) {
      return const GoogleSignInResult.failed(
        'Google sign-in is not available in this build.',
      );
    }

    try {
      // Always start from a clean slate so the account chooser appears and a
      // fresh ID token is issued rather than a possibly-stale cached one.
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return const GoogleSignInResult.cancelled();
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return const GoogleSignInResult.failed(
          'Google did not return a sign-in token. Please try again.',
        );
      }
      return GoogleSignInResult.success(idToken);
    } catch (error) {
      return GoogleSignInResult.failed('Google sign-in failed: $error');
    }
  }

  /// Clears the cached Google account so the next sign-in shows the chooser.
  /// Best-effort — failures are swallowed since app sign-out proceeds anyway.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore — local app session is cleared regardless.
    }
  }
}
