import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';

class PdfDownloadException implements Exception {
  final String message;

  const PdfDownloadException(this.message);

  @override
  String toString() => message;
}

class PdfDownloadWorkflow {
  static const MethodChannel _channel = MethodChannel('quick_al/downloads');

  static Future<String> generateAndDownload({
    required String endpoint,
    required Map<String, Object?> payload,
    required String generationFailureMessage,
  }) async {
    final http.Response response = await AuthHttpClient().post(
      ApiConfig.buildUri(endpoint),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PdfDownloadException(generationFailureMessage);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const PdfDownloadException(
        'PDF service returned an invalid response.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const PdfDownloadException('PDF file link not returned by server.');
    }

    final String fileName = _readString(decoded['fileName']);
    final String downloadUrl = _readString(decoded['downloadUrl']);
    if (fileName.isEmpty || downloadUrl.isEmpty) {
      throw const PdfDownloadException('PDF file link not returned by server.');
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const PdfDownloadException(
        'PDF download to Downloads is currently supported on Android only.',
      );
    }

    try {
      await _channel.invokeMethod<void>('downloadPdf', <String, String>{
        'url': ApiConfig.resolveUrl(downloadUrl),
        'fileName': fileName,
        'description': 'Downloading PDF to Downloads',
      });
    } on PlatformException catch (error) {
      throw PdfDownloadException(
        error.message ?? 'Unable to save PDF in Downloads.',
      );
    }

    return fileName;
  }

  static String _readString(Object? value) {
    return value is String ? value.trim() : '';
  }
}
