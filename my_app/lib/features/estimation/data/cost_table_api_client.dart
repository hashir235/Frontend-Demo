import 'dart:convert';

import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';
import 'package:http/http.dart' as http;

import '../models/optimization_error_text.dart';
import '../models/cost_table.dart';

class CostTableApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const CostTableApiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => message;
}

class CostTableApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;

  CostTableApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? AuthHttpClient(),
      _endpointUri = Uri.parse(
        '${baseUrl ?? ApiConfig.baseUrl}/api/cost-table',
      );

  Future<CostTable> fetchCostTable({
    required String gauge,
    required String color,
    String? projectId,
    List<RateOverrideInput> overrides = const <RateOverrideInput>[],
    String context = 'estimation',
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        _endpointUri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object?>{
          'gauge': gauge,
          'color': color,
          'projectId': projectId,
          'context': context,
          'overrides': overrides
              .map((RateOverrideInput item) => item.toJson())
              .toList(),
        }),
      );
    } on Exception catch (error) {
      throw CostTableApiException(
        OptimizationErrorText.forTransport(error).combined,
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String? raw = payload?['error'] as String?;
      throw CostTableApiException(
        raw != null
            ? OptimizationErrorText.explain(raw).combined
            : OptimizationErrorText.forTransport(
                Exception('cost table failed'),
                statusCode: response.statusCode,
              ).combined,
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw CostTableApiException(
        OptimizationErrorText.forTransport(
          Exception('cost table failed'),
          statusCode: 502,
        ).combined,
      );
    }

    final CostTable table = CostTable.fromJson(payload);
    if (!table.ok) {
      throw CostTableApiException(
        table.errors.isEmpty
            ? OptimizationErrorText.explain('cost table failed').combined
            : OptimizationErrorText.friendlyAll(table.errors).join('\n\n'),
        statusCode: response.statusCode,
        detail: table.errors,
      );
    }
    return table;
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
