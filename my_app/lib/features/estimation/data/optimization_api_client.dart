import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/cutting_report.dart';
import '../models/optimization_request.dart';
import '../models/section_recalculation.dart';

class OptimizationApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const OptimizationApiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => message;
}

class OptimizationApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;
  final Uri _sectionRecalculationUri;

  OptimizationApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _endpointUri = Uri.parse(
        '${baseUrl ?? _defaultBaseUrl()}/api/estimation/length-optimization',
      ),
      _sectionRecalculationUri = Uri.parse(
        '${baseUrl ?? _defaultBaseUrl()}/api/optimization/recalculate-section',
      );

  Future<CuttingReport> fetchLengthOptimization(OptimizationRequest request) {
    return _postForReport(
      _endpointUri,
      request.toJson(),
      unreachableMessage: 'Unable to reach local optimization service.',
      invalidJsonMessage: 'Optimization service returned invalid JSON.',
      failedStatusMessage: 'Optimization request failed with status',
    );
  }

  Future<CuttingReport> recalculateSection(
    SectionRecalculationRequest request,
  ) {
    return _postForReport(
      _sectionRecalculationUri,
      request.toJson(),
      unreachableMessage: 'Unable to reach local recalculation service.',
      invalidJsonMessage: 'Recalculation service returned invalid JSON.',
      failedStatusMessage: 'Recalculation request failed with status',
    );
  }

  Future<CuttingReport> _postForReport(
    Uri endpoint,
    Map<String, dynamic> body, {
    required String unreachableMessage,
    required String invalidJsonMessage,
    required String failedStatusMessage,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        endpoint,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } on Exception catch (error) {
      throw OptimizationApiException(unreachableMessage, detail: error);
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OptimizationApiException(
        (payload?['error'] as String?) ??
            '$failedStatusMessage ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw OptimizationApiException(invalidJsonMessage);
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
