import 'dart:convert';
import 'dart:typed_data';

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

  /// Invoked when an authenticated request comes back 403 because the account
  /// has been switched off, carrying the reason its owner is to be shown.
  ///
  /// Separate from [onUnauthorized] because it is the opposite situation: the
  /// session is perfectly valid, and signing out would lose the one thing that
  /// lets the shop carry on the moment it is switched back on.
  static void Function(String message)? onAccountBlocked;

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
    if (sentWithToken && response.statusCode == 403) {
      return _checkForBlock(response);
    }
    return response;
  }

  /// Looks inside a 403 for the "this account is switched off" refusal.
  ///
  /// Reading the body consumes the stream, so it is buffered and handed back
  /// as a fresh response -- the caller still gets an intact one and cannot
  /// tell this happened. Only 403 is buffered; every other reply streams
  /// through untouched, which is what a report of any size depends on.
  Future<http.StreamedResponse> _checkForBlock(
    http.StreamedResponse response,
  ) async {
    final Uint8List bytes = await response.stream.toBytes();
    try {
      final Object? parsed = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      if (parsed is Map<String, dynamic> && parsed['code'] == 'account_blocked') {
        final String message = (parsed['error'] as String?)?.trim() ?? '';
        if (message.isNotEmpty) onAccountBlocked?.call(message);
      }
    } on FormatException {
      // A 403 that is not ours -- a proxy, say. Nothing to read, and the
      // caller still gets the body to make its own sense of.
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
