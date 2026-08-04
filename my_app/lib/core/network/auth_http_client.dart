import 'package:http/http.dart' as http;
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/features/auth/state/auth_session.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;

  /// Read once and kept, so every request does not hit the platform channel.
  static String? _appVersion;

  static Future<String> _versionOnce() async {
    final String? cached = _appVersion;
    if (cached != null) return cached;
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      return _appVersion = '';
    }
  }

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

    // Tells the backend whether this copy came from Play Store or the website
    // APK, and which build it is. Without it the owner's dashboard cannot tell
    // the two sets of users apart. Sent only on authenticated requests -- it
    // is about the signed-in user, not about anonymous traffic.
    if (sentWithToken) {
      request.headers['x-quickal-channel'] = ApiConfig.subscriptionChannel;
      final String version = await _versionOnce();
      if (version.isNotEmpty) {
        request.headers['x-quickal-app-version'] = version;
      }
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
