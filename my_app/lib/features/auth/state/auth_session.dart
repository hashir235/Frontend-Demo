import '../models/auth_session_result.dart';
import '../models/auth_user.dart';

class AuthSession {
  AuthSession._();

  static String? _token;
  static AuthUser? _user;

  static String? get token => _token;
  static AuthUser? get user => _user;

  static bool get isAuthenticated =>
      (_token != null && _token!.isNotEmpty) && _user != null;

  static void apply(AuthSessionResult session) {
    _token = session.token;
    _user = session.user;
  }

  static void clear() {
    _token = null;
    _user = null;
  }
}
