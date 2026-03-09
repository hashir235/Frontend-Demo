import 'package:http/http.dart' as http;
import 'package:my_app/features/auth/state/auth_session.dart';

class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;

  AuthHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final String? token = AuthSession.token;
    if (token != null &&
        token.isNotEmpty &&
        !request.headers.containsKey('Authorization')) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return _inner.send(request);
  }
}
