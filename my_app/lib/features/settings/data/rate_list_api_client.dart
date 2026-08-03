import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';

import '../models/rate_list.dart';

class RateListApiException implements Exception {
  final String message;
  final int? statusCode;

  const RateListApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Talks to the per-user rate list.
///
/// The owner uploads one master list; each user keeps their own copy and edits
/// it. Fetching returns whichever is in force plus the master, so the screen
/// can show what a value would go back to.
class RateListApiClient {
  final http.Client _httpClient;
  final Uri _uri;

  RateListApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? AuthHttpClient(),
      _uri = Uri.parse('${baseUrl ?? ApiConfig.baseUrl}/api/settings/rates');

  Future<RateList> fetch() => _send(() => _httpClient.get(_uri));

  Future<RateList> save(List<RateRow> rows) => _send(
    () => _httpClient.put(
      _uri,
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, Object?>{
        'rates': rows.map((RateRow r) => r.toJson()).toList(),
      }),
    ),
  );

  /// Drop this user's edits and follow the owner's list again.
  Future<RateList> resetToMaster() => _send(() => _httpClient.delete(_uri));

  Future<RateList> _send(Future<http.Response> Function() call) async {
    late final http.Response response;
    try {
      response = await call();
    } on Exception {
      throw const RateListApiException(
        'Could not reach the rates service. Check your connection.',
      );
    }

    Map<String, dynamic>? payload;
    if (response.body.trim().isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) payload = decoded;
      } on FormatException {
        payload = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RateListApiException(
        (payload?['error'] as String?) ??
            'Rates request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    if (payload == null) {
      throw const RateListApiException('Rates service returned invalid JSON.');
    }
    return RateList.fromJson(payload);
  }
}
