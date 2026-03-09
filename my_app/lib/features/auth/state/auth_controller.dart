import 'package:flutter/foundation.dart';

import '../data/auth_api_client.dart';
import '../data/auth_session_store.dart';
import '../models/auth_session_result.dart';
import '../models/auth_user.dart';
import 'auth_session.dart';

class AuthController extends ChangeNotifier {
  AuthController._();

  static final AuthController instance = AuthController._();

  final AuthApiClient _apiClient = AuthApiClient();
  final AuthSessionStore _sessionStore = AuthSessionStore();

  bool _busy = false;
  bool _initialized = false;
  String? _errorMessage;
  Future<void>? _restoreFuture;

  bool get isBusy => _busy;
  bool get isInitialized => _initialized;
  bool get isAuthenticated => AuthSession.isAuthenticated;
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
  }) {
    return _runSessionAction(
      () => _apiClient.register(
        fullName: fullName,
        email: email,
        password: password,
      ),
    );
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

    AuthSession.clear();
    await _sessionStore.clear();
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

  Future<bool> _runSessionAction(
    Future<AuthSessionResult> Function() action,
  ) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final AuthSessionResult session = await action();
      AuthSession.apply(session);
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
      } else {
        AuthSession.apply(activeSession);
      }
    } catch (_) {
      AuthSession.clear();
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
