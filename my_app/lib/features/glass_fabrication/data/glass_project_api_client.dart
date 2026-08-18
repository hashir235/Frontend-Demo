import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/auth_http_client.dart';

class GlassProjectApiException implements Exception {
  final String message;
  const GlassProjectApiException(this.message);

  @override
  String toString() => message;
}

/// The glass job that belongs to an aluminium one.
class GlassProjectHandover {
  final String projectId;
  final String projectName;
  final String projectLocation;

  /// True when this job had already been opened before — the button was
  /// pressed a second time and we reopened rather than duplicated.
  final bool reused;

  const GlassProjectHandover({
    required this.projectId,
    required this.projectName,
    required this.projectLocation,
    required this.reused,
  });
}

class GlassProjectApiClient {
  final http.Client _client;

  GlassProjectApiClient({http.Client? client})
    : _client = client ?? AuthHttpClient();

  /// Opens the glass side of an aluminium job, sizes already in place.
  ///
  /// The whole point is that the fabricator does nothing: no new project to
  /// name, no sizes to retype. The engine worked the glass list out while
  /// cutting the aluminium, and this carries it across.
  Future<GlassProjectHandover> openGlassSideOf(String aluminiumProjectId) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/projects/glass-from-aluminium',
            ),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'projectId': aluminiumProjectId,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on Exception catch (_) {
      throw const GlassProjectApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    Map<String, dynamic>? body;
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // The server's own wording: it refuses for reasons the user can act on,
      // such as the cutting report not having been run yet.
      throw GlassProjectApiException(
        (body?['error'] as String?) ?? 'Could not open the glass job.',
      );
    }

    final Map<String, dynamic>? project =
        body?['project'] as Map<String, dynamic>?;
    if (project == null) {
      throw const GlassProjectApiException('Could not open the glass job.');
    }

    return GlassProjectHandover(
      projectId: project['id'] as String? ?? '',
      projectName: project['projectName'] as String? ?? '',
      projectLocation: project['projectLocation'] as String? ?? '',
      reused: body?['reused'] == true,
    );
  }
}
