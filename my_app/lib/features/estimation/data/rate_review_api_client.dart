import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/rate_review.dart';

class RateReviewApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const RateReviewApiException(
    this.message, {
    this.statusCode,
    this.detail,
  });

  @override
  String toString() => message;
}

class RateReviewApiClient {
  final http.Client _httpClient;
  final Uri _endpointUri;

  RateReviewApiClient({
    http.Client? httpClient,
    String? baseUrl,
  }) : _httpClient = httpClient ?? http.Client(),
       _endpointUri = Uri.parse(
         '${baseUrl ?? _defaultBaseUrl()}/api/rate-review',
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
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, Object?>{
          'gauge': gauge,
          'color': color,
          'projectId': projectId,
          'context': context,
        }),
      );
    } on Exception catch (error) {
      throw RateReviewApiException(
        'Unable to reach local rate service.',
        detail: error,
      );
    }

    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message =
          (payload?['error'] as String?) ??
          'Rate request failed with status ${response.statusCode}.';
      final Object? detail = payload?['detail'];
      if (detail is Map<String, dynamic>) {
        final String stderr = ((detail['stderr'] as String?) ?? '').trim();
        if (stderr.isNotEmpty) {
          message = '$message: $stderr';
        }
      }
      throw RateReviewApiException(
        message,
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }

    if (payload == null) {
      throw const RateReviewApiException(
        'Rate service returned invalid JSON.',
      );
    }

    final RateReview review = RateReview.fromJson(payload);
    if (!review.ok) {
      throw RateReviewApiException(
        review.errors.isEmpty
            ? 'Rate service returned an unsuccessful result.'
            : review.errors.join('\n'),
        statusCode: response.statusCode,
        detail: review.errors,
      );
    }
    return review;
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
