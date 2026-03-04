import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/billing_settings.dart';

class BillingSettingsApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const BillingSettingsApiException(
    this.message, {
    this.statusCode,
    this.detail,
  });

  @override
  String toString() => message;
}

class BillingSettingsApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;

  BillingSettingsApiClient({
    http.Client? httpClient,
    String? baseUrl,
  }) : _httpClient = httpClient ?? http.Client(),
       _endpointUri = Uri.parse(
         '${baseUrl ?? _defaultBaseUrl()}/api/settings/billing',
       );

  Future<BillingSettingsModel> fetchBillingSettings() async {
    late final http.Response response;
    try {
      response = await _httpClient.get(_endpointUri);
    } on Exception catch (error) {
      throw BillingSettingsApiException(
        'Unable to reach local settings service.',
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BillingSettingsApiException(
        (payload?['error'] as String?) ??
            'Settings request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw const BillingSettingsApiException(
        'Settings service returned invalid JSON.',
      );
    }

    return BillingSettingsModel.fromJson(payload);
  }

  Future<BillingSettingsModel> saveBillingSettings(
    BillingSettingsModel settings,
  ) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        _endpointUri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(settings.toJson()),
      );
    } on Exception catch (error) {
      throw BillingSettingsApiException(
        'Unable to reach local settings service.',
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BillingSettingsApiException(
        (payload?['error'] as String?) ??
            'Settings save failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw const BillingSettingsApiException(
        'Settings service returned invalid JSON.',
      );
    }

    return BillingSettingsModel.fromJson(payload);
  }

  static String _defaultBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
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
