import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session_result.dart';

class AuthSessionStore {
  static const String _sessionKey = 'quick_al.auth_session';

  Future<void> persist(AuthSessionResult session) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<AuthSessionResult?> restore() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? rawSession = preferences.getString(_sessionKey);
    if (rawSession == null || rawSession.trim().isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(rawSession);
      if (decoded is! Map) {
        return null;
      }
      return AuthSessionResult.fromJson(decoded.cast<String, dynamic>());
    } on FormatException {
      return null;
    }
  }

  Future<void> clear() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
