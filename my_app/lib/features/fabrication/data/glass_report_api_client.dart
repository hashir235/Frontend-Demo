import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/glass_report.dart';

class GlassReportApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const GlassReportApiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => message;
}

class GlassReportApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;

  GlassReportApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _endpointUri = Uri.parse(
        '${baseUrl ?? _defaultBaseUrl()}/api/glass-report',
      );

  Future<GlassReport> fetchGlassReport({String? projectId}) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        _endpointUri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object?>{'projectId': projectId}),
      );
    } on Exception catch (error) {
      throw GlassReportApiException(
        'Unable to reach local glass report service.',
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message =
          (payload?['error'] as String?) ??
          'Glass report request failed with status ${response.statusCode}.';
      final Object? detail = payload?['detail'];
      if (detail is Map<String, dynamic>) {
        final String stderr = ((detail['stderr'] as String?) ?? '').trim();
        if (stderr.isNotEmpty) {
          message = '$message: $stderr';
        }
      }
      throw GlassReportApiException(
        message,
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw const GlassReportApiException(
        'Glass report service returned invalid JSON.',
      );
    }

    final GlassReport report = GlassReport.fromJson(payload);
    if (!report.ok) {
      throw GlassReportApiException(
        report.errors.isEmpty
            ? 'Glass report service returned an unsuccessful result.'
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
