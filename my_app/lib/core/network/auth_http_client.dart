import 'package:http/http.dart' as http;
import 'package:my_app/features/auth/state/auth_session.dart';

class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;

  /// Invoked when an authenticated request (one that carried a token) returns
  /// 401 — meaning the session is no longer valid, typically because the
  /// account was signed in on another device (single-device enforcement).
  /// [AuthController] registers this to sign the user out locally.
  static void Function()? onUnauthorized;

  AuthHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String? token = AuthSession.token;
    final bool sentWithToken = token != null && token.isNotEmpty;
    if (sentWithToken && !request.headers.containsKey('Authorization')) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final http.StreamedResponse response = await _inner.send(request);

    // Reading statusCode does not consume the body stream, so the caller still
    // receives an intact response.
    if (sentWithToken && response.statusCode == 401) {
      onUnauthorized?.call();
    }
    return response;
  }
}
