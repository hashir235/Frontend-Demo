import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/auth_http_client.dart';
import '../data/auth_api_client.dart';
import '../data/auth_session_store.dart';
import '../data/google_sign_in_service.dart';
import '../models/auth_session_result.dart';
import '../models/auth_user.dart';
import 'auth_session.dart';

class AuthController extends ChangeNotifier {
  AuthController._() {
    // Single-device enforcement: when any authenticated request comes back 401
    // (the server invalidated this session because the account signed in
    // elsewhere), sign out locally so the app returns to the login screen.
    AuthHttpClient.onUnauthorized = _onRemoteSessionInvalidated;
  }

  static final AuthController instance = AuthController._();

  final AuthApiClient _apiClient = AuthApiClient();
  final AuthSessionStore _sessionStore = AuthSessionStore();
  final GoogleSignInService _googleSignIn = GoogleSignInService();

  bool _busy = false;
  bool _initialized = false;
  bool _needsWorkshopSetup = false;
  String? _errorMessage;
  Future<void>? _restoreFuture;

  bool get isBusy => _busy;
  bool get isInitialized => _initialized;
  bool get isAuthenticated => AuthSession.isAuthenticated;

  /// True while the signed-in account still has to enter its workshop details.
  /// The app gate shows the workshop onboarding screen instead of Home until
  /// the user saves them (or skips for the session).
  bool get needsWorkshopSetup => _needsWorkshopSetup && isAuthenticated;
  String? get errorMessage => _errorMessage;
  AuthUser? get currentUser => AuthSession.user;

  Future<void> ensureInitialized() {
    return _restoreFuture ??= _restoreSession();
  }

  Future<bool> signIn({required String email, required String password}) {
    return _runSessionAction(
      () => _apiClient.login(email: email, password: password),
    );
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    String workshopName = '',
    String workshopPhone = '',
    String workshopAddress = '',
  }) {
    return _runSessionAction(
      () => _apiClient.register(
        fullName: fullName,
        email: email,
        password: password,
        workshopName: workshopName,
        workshopPhone: workshopPhone,
        workshopAddress: workshopAddress,
      ),
    );
  }

  /// Runs the Google account picker, exchanges the ID token for an app session,
  /// and signs the user in. Returns true on success. A user who dismisses the
  /// Google chooser gets `false` with no error message (a silent cancel).
  Future<bool> signInWithGoogle() async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    final GoogleSignInResult google = await _googleSignIn.signIn();
    if (google.outcome == GoogleSignInOutcome.cancelled) {
      _busy = false;
      notifyListeners();
      return false;
    }
    if (google.outcome == GoogleSignInOutcome.failed) {
      _errorMessage = google.errorMessage ?? 'Google sign-in failed.';
      _busy = false;
      notifyListeners();
      return false;
    }

    try {
      final AuthSessionResult session = await _apiClient.signInWithGoogle(
        idToken: google.idToken!,
      );
      AuthSession.apply(session);
      _needsWorkshopSetup = session.needsWorkshopSetup;
      await _persistSession(session);
      _busy = false;
      notifyListeners();
      return true;
    } on AuthApiException catch (error) {
      _errorMessage = error.message;
      _busy = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Google sign-in failed unexpectedly.';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Called when the user saves their workshop details from the onboarding
  /// screen. Clears the flag and re-persists the session so the app never shows
  /// onboarding again for this account, even offline.
  Future<void> markWorkshopSetupComplete() async {
    if (!_needsWorkshopSetup) {
      return;
    }
    _needsWorkshopSetup = false;
    final AuthSessionResult? stored = await _sessionStore.restore();
    if (stored != null) {
      await _persistSession(stored.copyWith(needsWorkshopSetup: false));
    }
    notifyListeners();
  }

  /// Dismisses the workshop onboarding for this session only (the "Skip for now"
  /// action). The stored flag is left as-is, so the prompt returns on the next
  /// launch until the details are actually saved.
  void skipWorkshopSetupForNow() {
    if (!_needsWorkshopSetup) {
      return;
    }
    _needsWorkshopSetup = false;
    notifyListeners();
  }

  Future<PasswordResetRequestResult?> requestPasswordReset({
    required String email,
  }) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final PasswordResetRequestResult result = await _apiClient
          .requestPasswordReset(email: email);
      _busy = false;
      notifyListeners();
      return result;
    } on AuthApiException catch (error) {
      _errorMessage = error.message;
      _busy = false;
      notifyListeners();
      return null;
    } catch (_) {
      _errorMessage = 'Password reset request failed unexpectedly.';
      _busy = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> confirmPasswordReset({
    required String email,
    required String code,
    required String password,
  }) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.confirmPasswordReset(
        email: email,
        code: code,
        password: password,
      );
      _busy = false;
      notifyListeners();
      return true;
    } on AuthApiException catch (error) {
      _errorMessage = error.message;
      _busy = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Password reset failed unexpectedly.';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.logout();
    } catch (_) {
      // Ignore logout failures and clear local state regardless.
    }

    await _googleSignIn.signOut();
    AuthSession.clear();
    await _sessionStore.clear();
    _needsWorkshopSetup = false;
    _busy = false;
    notifyListeners();
  }

  /// Deletes the account on the server, then clears this device exactly as a
  /// sign-out would.
  ///
  /// Unlike [signOut], a failure here is not swallowed: telling someone their
  /// account is gone when it is not would be the worst possible outcome, so the
  /// error is thrown and local state is left alone.
  Future<void> deleteAccount() async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.deleteAccount();
    } catch (error) {
      _busy = false;
      _errorMessage = error.toString();
      notifyListeners();
      rethrow;
    }

    // The account is gone; the session it belonged to cannot be revoked, so
    // this only tidies up the device.
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Signing out of Google locally is a courtesy, not a requirement.
    }
    AuthSession.clear();
    await _sessionStore.clear();
    _needsWorkshopSetup = false;
    _busy = false;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  /// Called when the backend reports this session is no longer valid (401 on an
  /// authenticated request) — almost always because the account was opened on
  /// another device. Clears local state only; the server session is already
  /// gone, so no logout call is made (which also avoids a request loop).
  void _onRemoteSessionInvalidated() {
    if (!AuthSession.isAuthenticated) {
      return;
    }
    AuthSession.clear();
    unawaited(_sessionStore.clear());
    unawaited(_googleSignIn.signOut());
    _needsWorkshopSetup = false;
    _busy = false;
    _errorMessage =
        'You were signed out because your account was opened on another device.';
    notifyListeners();
  }

  Future<bool> _runSessionAction(
    Future<AuthSessionResult> Function() action,
  ) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final AuthSessionResult session = await action();
      AuthSession.apply(session);
      _needsWorkshopSetup = session.needsWorkshopSetup;
      await _persistSession(session);
      _busy = false;
      notifyListeners();
      return true;
    } on AuthApiException catch (error) {
      _errorMessage = error.message;
      _busy = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Authentication request failed unexpectedly.';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _restoreSession() async {
    _errorMessage = null;

    try {
      final AuthSessionResult? storedSession = await _sessionStore.restore();
      if (!_isRestorable(storedSession)) {
        AuthSession.clear();
        await _sessionStore.clear();
        _initialized = true;
        notifyListeners();
        return;
      }

      AuthSessionResult? activeSession = storedSession;
      try {
        activeSession = await _apiClient.fetchCurrentSession(
          token: storedSession!.token,
        );
        await _persistSession(activeSession);
      } on AuthApiException catch (error) {
        final bool isUnauthorized =
            error.statusCode == 401 || error.statusCode == 403;
        if (isUnauthorized) {
          activeSession = null;
          await _sessionStore.clear();
        }
      } catch (_) {
        // Preserve the cached session when the backend is temporarily unreachable.
      }

      if (activeSession == null) {
        AuthSession.clear();
        _needsWorkshopSetup = false;
      } else {
        AuthSession.apply(activeSession);
        _needsWorkshopSetup = activeSession.needsWorkshopSetup;
      }
    } catch (_) {
      AuthSession.clear();
      _needsWorkshopSetup = false;
    }

    _initialized = true;
    notifyListeners();
  }

  bool _isRestorable(AuthSessionResult? session) {
    if (session == null ||
        session.token.trim().isEmpty ||
        session.user.id.isEmpty) {
      return false;
    }
    final DateTime? expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return true;
    }
    return expiresAt.isAfter(DateTime.now());
  }

  Future<void> _persistSession(AuthSessionResult session) async {
    try {
      await _sessionStore.persist(session);
    } catch (_) {
      // Keep the in-memory session even if local persistence fails.
    }
  }
}
