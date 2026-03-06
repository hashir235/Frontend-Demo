import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/saved_project.dart';
import '../models/window_review_item.dart';

class ProjectApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? detail;

  const ProjectApiException(
    this.message, {
    this.statusCode,
    this.detail,
  });

  @override
  String toString() => message;
}

class ProjectApiClient {
  final http.Client _httpClient;
  final String _baseUrl;

  ProjectApiClient({
    http.Client? httpClient,
    String? baseUrl,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? _defaultBaseUrl();

  Future<SavedProjectDetail> createProject({
    required String context,
    required String projectName,
    required String projectLocation,
  }) async {
    final Map<String, dynamic> payload = await _postJson(
      Uri.parse('$_baseUrl/api/projects'),
      <String, Object?>{
        'context': context,
        'projectName': projectName,
        'projectLocation': projectLocation,
      },
      unreachableMessage: 'Unable to reach local project service.',
      failureMessage: 'Project create failed.',
    );
    return SavedProjectDetail.fromJson(payload);
  }

  Future<List<SavedProjectSummary>> fetchRecentProjects({
    required String context,
    int limit = 30,
  }) async {
    final Uri uri = Uri.parse(
      '$_baseUrl/api/projects/recent?context=$context&limit=$limit',
    );
    final Map<String, dynamic> payload = await _getJson(
      uri,
      unreachableMessage: 'Unable to reach local project service.',
      failureMessage: 'Recent projects load failed.',
    );
    final List<dynamic> rawProjects =
        payload['projects'] is List<dynamic> ? payload['projects'] as List<dynamic> : <dynamic>[];
    return rawProjects
        .whereType<Map<String, dynamic>>()
        .map(SavedProjectSummary.fromJson)
        .toList(growable: false);
  }

  Future<SavedProjectDetail> fetchProject(String projectId) async {
    final Map<String, dynamic> payload = await _getJson(
      Uri.parse('$_baseUrl/api/projects/$projectId'),
      unreachableMessage: 'Unable to reach local project service.',
      failureMessage: 'Project load failed.',
    );
    return SavedProjectDetail.fromJson(payload);
  }

  Future<SavedProjectDetail> saveProjectWindows({
    required String projectId,
    required List<WindowReviewItem> windows,
  }) async {
    final Map<String, dynamic> payload = await _putJson(
      Uri.parse('$_baseUrl/api/projects/$projectId/windows'),
      <String, Object?>{
        'windows': windows.map((WindowReviewItem item) => item.toJson()).toList(),
      },
      unreachableMessage: 'Unable to reach local project service.',
      failureMessage: 'Project save failed.',
    );
    return SavedProjectDetail.fromJson(payload);
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    required String unreachableMessage,
    required String failureMessage,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.get(uri);
    } on Exception catch (error) {
      throw ProjectApiException(unreachableMessage, detail: error);
    }
    return _decodeResponse(response, failureMessage);
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    required String unreachableMessage,
    required String failureMessage,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } on Exception catch (error) {
      throw ProjectApiException(unreachableMessage, detail: error);
    }
    return _decodeResponse(response, failureMessage);
  }

  Future<Map<String, dynamic>> _putJson(
    Uri uri,
    Map<String, Object?> body, {
    required String unreachableMessage,
    required String failureMessage,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.put(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } on Exception catch (error) {
      throw ProjectApiException(unreachableMessage, detail: error);
    }
    return _decodeResponse(response, failureMessage);
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
    String failureMessage,
  ) {
    final Map<String, dynamic>? payload = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProjectApiException(
        (payload?['error'] as String?) ??
            '$failureMessage Status ${response.statusCode}.',
        statusCode: response.statusCode,
        detail: payload?['detail'],
      );
    }
    if (payload == null) {
      throw const ProjectApiException('Project service returned invalid JSON.');
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

  static String _defaultBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }
}
