import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/cost_table.dart';

class CostTableApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const CostTableApiException(
    this.message, {
    this.statusCode,
    this.detail,
  });

  @override
  String toString() => message;
}

class CostTableApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;

  CostTableApiClient({
    http.Client? httpClient,
    String? baseUrl,
  }) : _httpClient = httpClient ?? http.Client(),
       _endpointUri = Uri.parse(
         '${baseUrl ?? _defaultBaseUrl()}/api/cost-table',
       );

  Future<CostTable> fetchCostTable({
    required String gauge,
    required String color,
    List<RateOverrideInput> overrides = const <RateOverrideInput>[],
    String context = 'estimation',
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        _endpointUri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, Object?>{
          'gauge': gauge,
          'color': color,
          'context': context,
          'overrides': overrides.map((RateOverrideInput item) => item.toJson()).toList(),
        }),
      );
    } on Exception catch (error) {
      throw CostTableApiException(
        'Unable to reach local cost table service.',
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CostTableApiException(
        (payload?['error'] as String?) ??
            'Cost table request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw const CostTableApiException(
        'Cost table service returned invalid JSON.',
      );
    }

    final CostTable table = CostTable.fromJson(payload);
    if (!table.ok) {
      throw CostTableApiException(
        table.errors.isEmpty
            ? 'Cost table service returned an unsuccessful result.'
            : table.errors.join('\n'),
        statusCode: response.statusCode,
        detail: table.errors,
      );
    }
    return table;
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
