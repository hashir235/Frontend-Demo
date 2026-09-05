import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/features/auth/models/auth_session_result.dart';
import 'package:my_app/features/auth/models/auth_user.dart';
import 'package:my_app/features/auth/state/auth_session.dart';

class AuthApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const AuthApiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => message;
}

class PasswordResetRequestResult {
  final String message;
  final String maskedEmail;
  final String? devResetCode;
  final int expiresInMinutes;

  const PasswordResetRequestResult({
    required this.message,
    required this.maskedEmail,
    required this.expiresInMinutes,
    this.devResetCode,
  });

  factory PasswordResetRequestResult.fromJson(Map<String, dynamic> json) {
    return PasswordResetRequestResult(
      message:
          (json['message'] as String?) ??
          'If this email is registered, a password reset code has been sent.',
      maskedEmail: (json['maskedEmail'] as String?) ?? '',
      devResetCode: json['devResetCode'] as String?,
      expiresInMinutes: (json['expiresInMinutes'] as num?)?.round() ?? 15,
    );
  }
}

class AuthApiClient {
  /// How long to wait for the server before calling the network dead.
  ///
  /// Without this a request on a stalled mobile connection hangs with the
  /// spinner turning until the user gives up, which reads as "the app is
  /// broken". Twenty seconds is well past a slow 3G round trip and well short
  /// of a person's patience.
  static const Duration _networkTimeout = Duration(seconds: 20);

  /// Shown whenever the request never reached us -- no DNS, no route, no TLS,
  /// or no answer in time.
  ///
  /// It deliberately does not blame the server: the app cannot tell a server
  /// outage from a phone that has dropped off the network, and the second is
  /// far more common. Naming the connection is both likelier to be true and
  /// the only half the user can act on.
  static const String _unreachable =
      'Could not reach Quick AL. Check your internet connection and try again.';

  final http.Client _httpClient;
  final String _baseUrl;

  AuthApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Registers an account. The workshop fields are optional and seed the user's
  /// billing settings, so invoices and PDFs carry the company identity from the
  /// first project instead of printing "--" until Settings is opened.
  Future<AuthSessionResult> register({
    required String fullName,
    required String email,
    required String password,
    String workshopName = '',
    String workshopPhone = '',
    String workshopAddress = '',
  }) async {
    final Map<String, dynamic> payload = await _postJson(
      Uri.parse('$_baseUrl/api/auth/register'),
      <String, Object?>{
        'fullName': fullName,
        'email': email,
        'password': password,
        if (workshopName.trim().isNotEmpty) 'workshopName': workshopName.trim(),
        if (workshopPhone.trim().isNotEmpty)
          'workshopPhone': workshopPhone.trim(),
        if (workshopAddress.trim().isNotEmpty)
          'workshopAddress': workshopAddress.trim(),
      },
      failureMessage: 'Registration failed.',
      unreachableMessage: _unreachable,
    );
    return AuthSessionResult.fromJson(payload);
  }

  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) async {
    final Map<String, dynamic> payload = await _postJson(
      Uri.parse('$_baseUrl/api/auth/login'),
      <String, Object?>{'email': email, 'password': password},
      failureMessage: 'Login failed.',
      unreachableMessage: _unreachable,
    );
    return AuthSessionResult.fromJson(payload);
  }

  /// Exchanges a verified Google ID token for an app session. The backend
  /// verifies the token, finds-or-creates the account, and returns
  /// `needsWorkshopSetup` so a first-time Google user is sent to onboarding.
  Future<AuthSessionResult> signInWithGoogle({required String idToken}) async {
    final Map<String, dynamic> payload = await _postJson(
      Uri.parse('$_baseUrl/api/auth/google'),
      <String, Object?>{'idToken': idToken},
      failureMessage: 'Google sign-in failed.',
      unreachableMessage: _unreachable,
    );
    return AuthSessionResult.fromJson(payload);
  }

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    final Map<String, dynamic> payload = await _postJson(
      Uri.parse('$_baseUrl/api/auth/password-reset/request'),
      <String, Object?>{'email': email},
      failureMessage: 'Password reset request failed.',
      unreachableMessage: _unreachable,
    );
    return PasswordResetRequestResult.fromJson(payload);
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String password,
  }) async {
    await _postJson(
      Uri.parse('$_baseUrl/api/auth/password-reset/confirm'),
      <String, Object?>{'email': email, 'code': code, 'password': password},
      failureMessage: 'Password reset failed.',
      unreachableMessage: _unreachable,
    );
  }

  Future<AuthSessionResult> fetchCurrentSession({String? token}) async {
    final String sessionToken = (token ?? AuthSession.token ?? '').trim();
    if (sessionToken.isEmpty) {
      throw const AuthApiException('Authentication token is missing.');
    }

    late final http.Response response;
    try {
      response = await _httpClient
          .get(
            Uri.parse('$_baseUrl/api/auth/me'),
            headers: <String, String>{
              'Authorization': 'Bearer $sessionToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_networkTimeout);
    } on Exception catch (error) {
      throw AuthApiException(_unreachable, detail: error);
    }

    final Map<String, dynamic> payload = _decodeResponse(
      response,
      'Session restore failed.',
    );
    return AuthSessionResult(
      user: AuthUser.fromJson(
        (payload['user'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      token: sessionToken,
      expiresAt: DateTime.tryParse(payload['expiresAt'] as String? ?? ''),
      needsWorkshopSetup: payload['needsWorkshopSetup'] == true,
    );
  }

  Future<void> logout() async {
    final String? token = AuthSession.token;
    if (token == null || token.isEmpty) {
      return;
    }

    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            Uri.parse('$_baseUrl/api/auth/logout'),
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_networkTimeout);
    } on Exception catch (error) {
      throw AuthApiException(_unreachable, detail: error);
    }

    _decodeResponse(response, 'Logout failed.');
  }

  /// Permanently deletes the signed-in account and everything belonging to it.
  ///
  /// The session is the proof of identity -- no password is asked for, and for
  /// this app none exists: people sign in with Google.
  Future<void> deleteAccount() async {
    final String? token = AuthSession.token;
    if (token == null || token.isEmpty) {
      throw const AuthApiException('You are not signed in.');
    }

    late final http.Response response;
    try {
      response = await _httpClient
          .delete(
            Uri.parse('$_baseUrl/api/account'),
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_networkTimeout);
    } on Exception catch (error) {
      throw AuthApiException(
        'Could not reach Quick AL. Check your connection and try again — '
        'nothing has been deleted.',
        detail: error,
      );
    }

    _decodeResponse(response, 'Account deletion failed.');
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    required String unreachableMessage,
    required String failureMessage,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_networkTimeout);
    } on Exception catch (error) {
      throw AuthApiException(unreachableMessage, detail: error);
    }
    return _decodeResponse(response, failureMessage);
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
    String failureMessage,
  ) {
    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        (payload?['error'] as String?) ??
            '$failureMessage Status ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }
    if (payload == null) {
      throw const AuthApiException(
        'Authentication service returned invalid JSON.',
      );
    }
    return payload;
  }

  Map<String, dynamic>? _decodeObject(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
