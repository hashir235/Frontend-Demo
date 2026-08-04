import 'dart:convert';

class AppNotification {
  final String id;
  final String type; // 'rate_update' | 'version_update' | 'general'
  final String title;
  final String body;
  final DateTime createdAt;

  /// APK url carried by a `version_update` notification (from its payload), so
  /// the notification can offer a one-tap update. Null for other types.
  final String? updateApkUrl;

  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.updateApkUrl,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? payload = _asMap(json['payload']);
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updateApkUrl: (payload?['apkUrl'] as String?)?.trim(),
    );
  }

  // Payload may arrive as a decoded object (jsonb) or a JSON string.
  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    if (value is String && value.trim().isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
