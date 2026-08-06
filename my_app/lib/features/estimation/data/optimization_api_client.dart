import 'dart:convert';

import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';
import 'package:http/http.dart' as http;

import '../models/cutting_report.dart';
import '../models/optimization_error_text.dart';
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
    : _httpClient = httpClient ?? AuthHttpClient(),
      _endpointUri = Uri.parse(
        '${baseUrl ?? ApiConfig.baseUrl}/api/estimation/length-optimization',
      ),
      _sectionRecalculationUri = Uri.parse(
        '${baseUrl ?? ApiConfig.baseUrl}/api/optimization/recalculate-section',
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
      // "Unable to reach local optimization service" means nothing to a user
      // whose phone simply lost signal, so the transport failure is named for
      // what it is.
      throw OptimizationApiException(
        OptimizationErrorText.forTransport(error).combined,
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String? serverMessage = payload?['error'] as String?;
      throw OptimizationApiException(
        serverMessage != null
            ? OptimizationErrorText.explain(serverMessage).combined
            : OptimizationErrorText.forTransport(
                Exception(failedStatusMessage),
                statusCode: response.statusCode,
              ).combined,
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      // A 200 with a body we cannot parse is the service misbehaving, not the
      // user's data.
      throw OptimizationApiException(
        OptimizationErrorText.forTransport(
          Exception(invalidJsonMessage),
          statusCode: 502,
        ).combined,
      );
    }

    final CuttingReport report = CuttingReport.fromJson(payload);
    if (!report.ok) {
      throw OptimizationApiException(
        report.errors.isEmpty
            ? 'The calculation did not finish\nPull down to refresh and try '
                  'again. If it keeps happening, check the window sizes and the '
                  'unit first.'
            : OptimizationErrorText.friendlyAll(report.errors).join('\n\n'),
        statusCode: response.statusCode,
        detail: report.errors,
      );
    }

    return report;
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
