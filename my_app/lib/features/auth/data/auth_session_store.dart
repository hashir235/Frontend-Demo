import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session_result.dart';

class AuthSessionStore {
  static const String _sessionKey = 'quick_al.auth_session';
  static const MethodChannel _secureStoreChannel = MethodChannel(
    'quick_al/secure_store',
  );

  Future<void> persist(AuthSessionResult session) async {
    final String payload = jsonEncode(session.toJson());
    if (await _writeSecure(payload)) {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.remove(_sessionKey);
      return;
    }
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, payload);
  }

  Future<AuthSessionResult?> restore() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    String? rawSession = await _readSecure();
    rawSession ??= preferences.getString(_sessionKey);
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
    await _deleteSecure();
    await preferences.remove(_sessionKey);
  }

  bool get _canUseNativeSecureStore {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  Future<bool> _writeSecure(String value) async {
    if (!_canUseNativeSecureStore) {
      return false;
    }
    try {
      await _secureStoreChannel.invokeMethod<void>('write', <String, String>{
        'key': _sessionKey,
        'value': value,
      });
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<String?> _readSecure() async {
    if (!_canUseNativeSecureStore) {
      return null;
    }
    try {
      return await _secureStoreChannel.invokeMethod<String>(
        'read',
        <String, String>{'key': _sessionKey},
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> _deleteSecure() async {
    if (!_canUseNativeSecureStore) {
      return;
    }
    try {
      await _secureStoreChannel.invokeMethod<void>('delete', <String, String>{
        'key': _sessionKey,
      });
    } on PlatformException {
      // Fallback storage is cleared separately.
    } on MissingPluginException {
      // Fallback storage is cleared separately.
    }
  }
}
