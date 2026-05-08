import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';

import '../models/glass_report.dart';
import '../models/glass_sheet_optimization.dart';

class GlassSheetOptimizationApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const GlassSheetOptimizationApiException(
    this.message, {
    this.statusCode,
    this.detail,
  });

  @override
  String toString() => message;
}

class GlassSheetOptimizationApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;

  GlassSheetOptimizationApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? AuthHttpClient(),
      _endpointUri = Uri.parse(
        '${baseUrl ?? ApiConfig.baseUrl}/api/glass-sheets/optimize',
      );

  Future<GlassSheetOptimizationResult> optimize({
    required GlassReport glassReport,
    required double sheetWidthFt,
    required double sheetHeightFt,
    required bool allowRotation,
    String? projectId,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        _endpointUri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object?>{
          'projectId': projectId,
          'sheetWidthFt': sheetWidthFt,
          'sheetHeightFt': sheetHeightFt,
          'allowRotation': allowRotation,
          'glassReport': glassReport.toJson(),
        }),
      );
    } on Exception catch (error) {
      throw GlassSheetOptimizationApiException(
        'Unable to reach glass sheet optimization service.',
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GlassSheetOptimizationApiException(
        (payload?['error'] as String?) ??
            'Glass sheet optimization failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw const GlassSheetOptimizationApiException(
        'Glass sheet optimization returned invalid JSON.',
      );
    }

    final GlassSheetOptimizationResult result =
        GlassSheetOptimizationResult.fromJson(payload);
    if (!result.ok) {
      throw GlassSheetOptimizationApiException(
        result.errors.isEmpty
            ? 'Glass sheet optimization returned an unsuccessful result.'
            : result.errors.join('\n'),
        statusCode: response.statusCode,
        detail: result.errors,
      );
    }
    return result;
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
