/// Keeping a workshop's formulas somewhere better than one phone.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';

import '../model/formula_overrides.dart';

class FormulaSyncException implements Exception {
  const FormulaSyncException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Carries a workshop's changed formulas to the server and back.
///
/// The device is where they have to be instantly readable; the server is where
/// they have to survive. A new phone, a reinstall, or the owner looking from
/// the office are all the same requirement, and none of them are met by
/// storage that lives inside one app on one handset.
///
/// The server stores and returns these without ever evaluating one. It does
/// not know what `(h + 6 + cm) / feet` means and does not need to: the app is
/// the single place that decides what a formula does. Two evaluators would
/// eventually disagree, and on the day they did a cutting sheet would be wrong
/// with nobody able to say which half was right.
class FormulaSyncApiClient {
  FormulaSyncApiClient({http.Client? httpClient, String? baseUrl})
      : _httpClient = httpClient ?? AuthHttpClient(),
        _endpointUri = Uri.parse(
          '${baseUrl ?? ApiConfig.baseUrl}/api/settings/formulas',
        );

  final http.Client _httpClient;
  final Uri _endpointUri;

  /// What this workshop has changed, as the server has it.
  Future<FormulaOverrides> fetch() async {
    late final http.Response response;
    try {
      response = await _httpClient.get(_endpointUri);
    } on Exception catch (error) {
      throw FormulaSyncException('Could not reach the formulas service: $error');
    }

    final Map<String, dynamic>? payload = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormulaSyncException(
        (payload?['error'] as String?) ??
            'Reading your formulas failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final Object? formulas = payload?['formulas'];
    if (formulas is! Map<String, dynamic>) return FormulaOverrides.empty();
    return FormulaOverrides.fromJson(formulas);
  }

  /// Records what this workshop has changed.
  Future<void> save(FormulaOverrides overrides) async {
    late final http.Response response;
    try {
      response = await _httpClient.put(
        _endpointUri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object?>{'formulas': overrides.toJson()}),
      );
    } on Exception catch (error) {
      throw FormulaSyncException('Could not reach the formulas service: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final Map<String, dynamic>? payload = _decode(response.body);
      throw FormulaSyncException(
        (payload?['error'] as String?) ??
            'Saving your formulas failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
  }

  static Map<String, dynamic>? _decode(String body) {
    try {
      final Object? parsed = jsonDecode(body);
      return parsed is Map<String, dynamic> ? parsed : null;
    } on FormatException {
      return null;
    }
  }
}
