import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';

import '../models/subscription_models.dart';

class SubscriptionApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const SubscriptionApiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => message;
}

class SubscriptionApiClient {
  final http.Client _httpClient;
  final String _baseUrl;

  SubscriptionApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? AuthHttpClient(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<SubscriptionCatalog> fetchPlans() async {
    final Map<String, dynamic> payload = await _getJson(
      Uri.parse(
        '$_baseUrl/api/subscription/plans?channel=${Uri.encodeQueryComponent(ApiConfig.subscriptionChannel)}',
      ),
      failureMessage: 'Subscription plans failed to load.',
    );
    return SubscriptionCatalog.fromJson(payload);
  }

  Future<SubscriptionStatus> fetchStatus() async {
    final Map<String, dynamic> payload = await _getJson(
      Uri.parse('$_baseUrl/api/subscription/status'),
      failureMessage: 'Subscription status failed to load.',
    );
    return SubscriptionStatus.fromJson(payload);
  }

  Future<({DirectPaymentRequest request, SubscriptionStatus status})>
  submitDirectPaymentRequest({
    required String planId,
    required String paymentMethod,
    required String paymentReference,
    String? payerName,
    String? payerPhone,
    int? amountPkr,
    String? notes,
  }) async {
    final Map<String, Object?> body = <String, Object?>{
      'planId': planId,
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
      if (payerName != null && payerName.trim().isNotEmpty)
        'payerName': payerName.trim(),
      if (payerPhone != null && payerPhone.trim().isNotEmpty)
        'payerPhone': payerPhone.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    if (amountPkr != null) {
      body['amountPkr'] = amountPkr;
    }

    final Map<String, dynamic> payload = await _postJson(
      Uri.parse('$_baseUrl/api/subscription/direct-payment-requests'),
      body,
      failureMessage: 'Direct payment request failed.',
    );
    final Map<String, dynamic> rawRequest =
        (payload['request'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final Map<String, dynamic> rawStatus =
        (payload['status'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    return (
      request: DirectPaymentRequest.fromJson(rawRequest),
      status: SubscriptionStatus.fromJson(rawStatus),
    );
  }

  Future<SubscriptionStatus> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    String? packageName,
  }) async {
    final Map<String, dynamic> payload = await _postJson(
      Uri.parse('$_baseUrl/api/subscription/google-play/verify'),
      <String, Object?>{
        'productId': productId,
        'purchaseToken': purchaseToken,
        if (packageName != null && packageName.trim().isNotEmpty)
          'packageName': packageName.trim(),
      },
      failureMessage: 'Subscription verification failed.',
    );
    return SubscriptionStatus.fromJson(payload);
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    required String failureMessage,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.get(
        uri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'x-quickal-channel': ApiConfig.subscriptionChannel,
        },
      );
    } on Exception catch (error) {
      throw SubscriptionApiException(
        'Unable to reach subscription service.',
        detail: error,
      );
    }
    return _decodeResponse(response, failureMessage);
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    required String failureMessage,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'x-quickal-channel': ApiConfig.subscriptionChannel,
        },
        body: jsonEncode(body),
      );
    } on Exception catch (error) {
      throw SubscriptionApiException(
        'Unable to reach subscription service.',
        detail: error,
      );
    }
    return _decodeResponse(response, failureMessage);
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
    String failureMessage,
  ) {
    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SubscriptionApiException(
        (payload?['error'] as String?) ??
            '$failureMessage Status ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }
    if (payload == null) {
      throw const SubscriptionApiException(
        'Subscription service returned invalid JSON.',
      );
    }
    return payload;
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
