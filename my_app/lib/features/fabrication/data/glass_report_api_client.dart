import 'dart:convert';

import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';
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
  final Uri _saveEndpointUri;

  GlassReportApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? AuthHttpClient(),
      _endpointUri = Uri.parse(
        '${baseUrl ?? ApiConfig.baseUrl}/api/glass-report',
      ),
      _saveEndpointUri = Uri.parse(
        '${baseUrl ?? ApiConfig.baseUrl}/api/glass-report/save',
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

  /// Persists an edited or manually-built glass report so the saved rows flow
  /// into the glass PDF and stay attached to the project. Returns the
  /// normalized report echoed back by the server.
  Future<GlassReport> saveGlassReport({
    required GlassReport report,
    String? projectId,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        _saveEndpointUri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object?>{
          'projectId': projectId,
          'projectName': report.projectName,
          'projectLocation': report.projectLocation,
          'rows': report.rows.map((GlassReportRow row) => row.toJson()).toList(),
        }),
      );
    } on Exception catch (error) {
      throw GlassReportApiException(
        'Unable to reach local glass report service.',
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GlassReportApiException(
        (payload?['error'] as String?) ??
            'Glass report save failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }
    if (payload == null) {
      throw const GlassReportApiException(
        'Glass report save returned invalid JSON.',
      );
    }
    return GlassReport.fromJson(payload);
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
