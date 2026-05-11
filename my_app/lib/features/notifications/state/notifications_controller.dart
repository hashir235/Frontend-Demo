import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/notifications_api_client.dart';
import '../models/app_notification.dart';

class NotificationsController extends ChangeNotifier {
  final NotificationsApiClient _client;

  NotificationsController(this._client);

  List<AppNotification> _notifications = [];
  bool _loading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  bool get loading => _loading;
  String? get error => _error;

  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final List<AppNotification> fetched = await _client.fetchNotifications();
      final Set<String> readIds = await _loadReadIds();
      for (final AppNotification n in fetched) {
        n.isRead = readIds.contains(n.id);
      }
      _notifications = fetched;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    final Set<String> ids = _notifications.map((n) => n.id).toSet();
    for (final AppNotification n in _notifications) {
      n.isRead = true;
    }
    await _saveReadIds(ids);
    notifyListeners();
  }

  Future<Set<String>> _loadReadIds() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> stored =
        prefs.getStringList('quickal_read_notification_ids') ?? [];
    return stored.toSet();
  }

  Future<void> _saveReadIds(Set<String> ids) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'quickal_read_notification_ids',
      ids.toList(),
    );
  }
}
