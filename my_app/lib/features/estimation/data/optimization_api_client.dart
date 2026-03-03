import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/cutting_report.dart';
import '../models/optimization_request.dart';

class OptimizationApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const OptimizationApiException(
    this.message, {
    this.statusCode,
    this.detail,
  });

  @override
  String toString() => message;
}

class OptimizationApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;

  OptimizationApiClient({
    http.Client? httpClient,
    String? baseUrl,
  }) : _httpClient = httpClient ?? http.Client(),
       _endpointUri = Uri.parse(
         '${baseUrl ?? _defaultBaseUrl()}/api/estimation/length-optimization',
       );

  Future<CuttingReport> fetchLengthOptimization(
    OptimizationRequest request,
  ) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        _endpointUri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );
    } on Exception catch (error) {
      throw OptimizationApiException(
        'Unable to reach local optimization service.',
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OptimizationApiException(
        (payload?['error'] as String?) ??
            'Optimization request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw const OptimizationApiException(
        'Optimization service returned invalid JSON.',
      );
    }

    final CuttingReport report = CuttingReport.fromJson(payload);
    if (!report.ok) {
      throw OptimizationApiException(
        report.errors.isEmpty
            ? 'Optimization service returned an unsuccessful result.'
            : report.errors.join('\n'),
        statusCode: response.statusCode,
        detail: report.errors,
      );
    }

    return report;
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
