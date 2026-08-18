import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/auth_http_client.dart';
import '../models/bill_defaults.dart';

class BillDefaultsApiException implements Exception {
  final String message;
  const BillDefaultsApiException(this.message);

  @override
  String toString() => message;
}

/// The rates a user saves once and has filled in on every bill.
class BillDefaultsApiClient {
  final AuthHttpClient _client;

  BillDefaultsApiClient({AuthHttpClient? client})
    : _client = client ?? AuthHttpClient();

  Uri get _uri => Uri.parse('${ApiConfig.baseUrl}/api/settings/bill-defaults');

  Future<BillDefaults> fetch() async {
    final http.Response response = await _client
        .get(_uri)
        .timeout(const Duration(seconds: 12));
    final Map<String, dynamic> body = _decode(response);
    return BillDefaults.fromJson(
      (body['defaults'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  Future<BillDefaults> save(BillDefaults defaults) async {
    final http.Response response = await _client
        .put(
          _uri,
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, Object?>{'defaults': defaults.toJson()}),
        )
        .timeout(const Duration(seconds: 12));
    final Map<String, dynamic> body = _decode(response);
    return BillDefaults.fromJson(
      (body['defaults'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const BillDefaultsApiException(
        'Could not reach your saved rates. Please try again.',
      );
    }
    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] == false) {
      throw BillDefaultsApiException(
        (body['error'] as String?) ?? 'Could not save your rates.',
      );
    }
    return body;
  }
}
