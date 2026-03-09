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

class AuthApiClient {
  final http.Client _httpClient;
  final String _baseUrl;

  AuthApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<AuthSessionResult> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final Map<String, dynamic> payload = await _postJson(
      Uri.parse('$_baseUrl/api/auth/register'),
      <String, Object?>{
        'fullName': fullName,
        'email': email,
        'password': password,
      },
      failureMessage: 'Registration failed.',
      unreachableMessage: 'Unable to reach authentication service.',
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
      unreachableMessage: 'Unable to reach authentication service.',
    );
    return AuthSessionResult.fromJson(payload);
  }

  Future<AuthSessionResult> fetchCurrentSession({String? token}) async {
    final String sessionToken = (token ?? AuthSession.token ?? '').trim();
    if (sessionToken.isEmpty) {
      throw const AuthApiException('Authentication token is missing.');
    }

    late final http.Response response;
    try {
      response = await _httpClient.get(
        Uri.parse('$_baseUrl/api/auth/me'),
        headers: <String, String>{
          'Authorization': 'Bearer $sessionToken',
          'Content-Type': 'application/json',
        },
      );
    } on Exception catch (error) {
      throw AuthApiException(
        'Unable to reach authentication service.',
        detail: error,
      );
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
    );
  }

  Future<void> logout() async {
    final String? token = AuthSession.token;
    if (token == null || token.isEmpty) {
      return;
    }

    late final http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/auth/logout'),
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } on Exception catch (error) {
      throw AuthApiException(
        'Unable to reach authentication service.',
        detail: error,
      );
    }

    _decodeResponse(response, 'Logout failed.');
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    required String unreachableMessage,
    required String failureMessage,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
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
