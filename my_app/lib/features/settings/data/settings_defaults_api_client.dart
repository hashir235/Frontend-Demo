import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';

/// Which block of settings to put back to how it shipped.
///
/// Section lengths are missing on purpose -- the server's template for them
/// carries only one section, so restoring from it would wipe the rest. The
/// settings screen restores those itself from the mill's standard bars.
enum SettingsGroup {
  cuttingMargins('cutting_margins'),
  lengthRules('length_rules'),
  fabricator('fabricator');

  const SettingsGroup(this.wireName);

  final String wireName;
}

class SettingsDefaultsException implements Exception {
  final String message;

  const SettingsDefaultsException(this.message);

  @override
  String toString() => message;
}

/// Puts a settings group back to the defaults Quick AL ships.
///
/// The numbers live in templates on the server, so the app never carries a
/// second copy that could drift out of step with them.
class SettingsDefaultsApiClient {
  final http.Client _httpClient;
  final Uri _uri;

  SettingsDefaultsApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? AuthHttpClient(),
      _uri = Uri.parse(
        '${baseUrl ?? ApiConfig.baseUrl}/api/settings/restore-defaults',
      );

  Future<void> restore(List<SettingsGroup> groups) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        _uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object?>{
          'groups': groups.map((SettingsGroup g) => g.wireName).toList(),
        }),
      );
    } on Exception {
      throw const SettingsDefaultsException(
        'Could not reach the settings service. Check your connection.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Restore failed (${response.statusCode}).';
      try {
        final Object? decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } on FormatException {
        // Keep the status-code message.
      }
      throw SettingsDefaultsException(message);
    }
  }
}
