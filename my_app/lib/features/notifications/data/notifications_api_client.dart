import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/auth_http_client.dart';
import '../models/app_notification.dart';

class NotificationsApiClient {
  final AuthHttpClient _client;

  NotificationsApiClient(this._client);

  Future<List<AppNotification>> fetchNotifications() async {
    final Uri uri = ApiConfig.buildUri('/api/notifications');
    final http.Response response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch notifications');
    }
    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> list = body['notifications'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
