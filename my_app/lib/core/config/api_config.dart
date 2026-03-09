import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _primaryBaseUrl = String.fromEnvironment(
    'QUICKAL_API_BASE_URL',
  );
  static const String _compatBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    final String configured = _firstConfiguredBaseUrl();
    if (configured.isNotEmpty) {
      return configured.replaceAll(RegExp(r'/+$'), '');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  static String _firstConfiguredBaseUrl() {
    final String primary = _primaryBaseUrl.trim();
    if (primary.isNotEmpty) {
      return primary;
    }
    return _compatBaseUrl.trim();
  }

  static Uri buildUri(String path) {
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }
}
