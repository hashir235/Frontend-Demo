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

/// What the server holds, and how new it is.
///
/// The revision is the whole point of asking: it is what tells a device
/// whether the copy on the server is newer than its own, and so whether a
/// formula set for this workshop from the office should replace what the
/// phone is carrying.
class RemoteFormulas {
  const RemoteFormulas({required this.overrides, required this.revision});

  const RemoteFormulas.none()
      : overrides = null,
        revision = 0;

  /// Null when the server has never been told anything for this workshop.
  final FormulaOverrides? overrides;

  /// Counts up by one on every accepted write. Zero means nothing stored.
  final int revision;
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
  Future<RemoteFormulas> fetch() async {
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
    if (formulas is! Map<String, dynamic>) return const RemoteFormulas.none();
    return RemoteFormulas(
      overrides: FormulaOverrides.fromJson(formulas),
      revision: _revisionIn(payload),
    );
  }

  /// Records what this workshop has changed, and reports which revision that
  /// became so the device can tell later whether the server has moved on
  /// without it.
  Future<int> save(FormulaOverrides overrides) async {
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

    final Map<String, dynamic>? payload = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormulaSyncException(
        (payload?['error'] as String?) ??
            'Saving your formulas failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
    return _revisionIn(payload);
  }

  /// An older server does not send one. Zero then means "no revision known",
  /// which leaves the device on its own copy rather than throwing it away
  /// over a field that was never there.
  static int _revisionIn(Map<String, dynamic>? payload) {
    final Object? raw = payload?['revision'];
    if (raw is int) return raw < 0 ? 0 : raw;
    if (raw is num) return raw < 0 ? 0 : raw.round();
    return 0;
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
