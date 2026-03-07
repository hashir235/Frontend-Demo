import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/bill_request.dart';
import '../models/bill_snapshot.dart';

class BillingApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const BillingApiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => message;
}

class BillingApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;

  BillingApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _endpointUri = Uri.parse(
        '${baseUrl ?? _defaultBaseUrl()}/api/billing/estimate',
      );

  Future<BillSnapshot> estimateBill(BillRequest request) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        _endpointUri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );
    } on Exception catch (error) {
      throw BillingApiException(
        'Unable to reach local billing service.',
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BillingApiException(
        (payload?['error'] as String?) ??
            'Billing request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw const BillingApiException('Billing service returned invalid JSON.');
    }

    final BillSnapshot snapshot = BillSnapshot.fromJson(payload);
    if (!snapshot.ok) {
      throw BillingApiException(
        snapshot.errors.isEmpty
            ? 'Billing service returned an unsuccessful result.'
            : snapshot.errors.join('\n'),
        statusCode: response.statusCode,
        detail: snapshot.errors,
      );
    }
    return snapshot;
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
