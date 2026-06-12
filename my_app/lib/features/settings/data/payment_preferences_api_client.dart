import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';

class PaymentPreferencesApiException implements Exception {
  final String message;
  final int? statusCode;

  const PaymentPreferencesApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Renewal mode for the user's subscription.
enum RenewalMode { manual, auto }

RenewalMode renewalModeFromString(String? raw) {
  return raw == 'auto' ? RenewalMode.auto : RenewalMode.manual;
}

String renewalModeToString(RenewalMode mode) {
  return mode == RenewalMode.auto ? 'auto' : 'manual';
}

class PaymentPreferencesApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;

  PaymentPreferencesApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? AuthHttpClient(),
      _endpointUri = Uri.parse(
        '${baseUrl ?? ApiConfig.baseUrl}/api/subscription/payment-preferences',
      );

  Future<RenewalMode> fetchRenewalMode() async {
    late final http.Response response;
    try {
      response = await _httpClient.get(_endpointUri);
    } on Exception {
      throw const PaymentPreferencesApiException(
        'Unable to reach the payment preferences service.',
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentPreferencesApiException(
        (payload?['error'] as String?) ??
            'Preferences request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic>? preferences =
        payload?['preferences'] as Map<String, dynamic>?;
    return renewalModeFromString(preferences?['renewalMode'] as String?);
  }

  Future<RenewalMode> saveRenewalMode(RenewalMode mode) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        _endpointUri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'renewalMode': renewalModeToString(mode),
        }),
      );
    } on Exception {
      throw const PaymentPreferencesApiException(
        'Unable to reach the payment preferences service.',
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentPreferencesApiException(
        (payload?['error'] as String?) ??
            'Preferences save failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic>? preferences =
        payload?['preferences'] as Map<String, dynamic>?;
    return renewalModeFromString(preferences?['renewalMode'] as String?);
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
