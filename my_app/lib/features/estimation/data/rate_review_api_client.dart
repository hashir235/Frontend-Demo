import 'dart:convert';

import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';
import 'package:http/http.dart' as http;

import '../models/optimization_error_text.dart';
import '../models/rate_review.dart';

class RateReviewApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const RateReviewApiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => message;
}

class RateReviewApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;

  RateReviewApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? AuthHttpClient(),
      _endpointUri = Uri.parse(
        '${baseUrl ?? ApiConfig.baseUrl}/api/rate-review',
      );

  Future<RateReview> fetchRateReview({
    required String gauge,
    required String color,
    String? projectId,
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
        }),
      );
    } on Exception catch (error) {
      throw RateReviewApiException(
        OptimizationErrorText.forTransport(error).combined,
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // The engine's own words arrive either in `error` or buried in the
      // process stderr; whichever we get, it goes through the same explainer so
      // "Missing rate for section D29" reads as something to act on.
      String? raw = payload?['error'] as String?;
      final Object? detail = payload?['detail'];
      if (detail is Map<String, dynamic>) {
        final String stderr = ((detail['stderr'] as String?) ?? '').trim();
        if (stderr.isNotEmpty) raw = stderr;
      }
      throw RateReviewApiException(
        raw != null
            ? OptimizationErrorText.explain(raw).combined
            : OptimizationErrorText.forTransport(
                Exception('rate review failed'),
                statusCode: response.statusCode,
              ).combined,
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw RateReviewApiException(
        OptimizationErrorText.forTransport(
          Exception('rate review failed'),
          statusCode: 502,
        ).combined,
      );
    }

    final RateReview review = RateReview.fromJson(payload);
    if (!review.ok) {
      throw RateReviewApiException(
        review.errors.isEmpty
            ? OptimizationErrorText.explain('rate review failed').combined
            : OptimizationErrorText.friendlyAll(review.errors).join('\n\n'),
        statusCode: response.statusCode,
        detail: review.errors,
      );
    }
    return review;
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
