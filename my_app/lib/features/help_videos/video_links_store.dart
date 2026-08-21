import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';

/// Where the help videos come from.
///
/// The server, not the app. There are seventeen of these to record and any of
/// them can be re-uploaded later — which changes its link — so keeping them in
/// the app would have meant a release, a Play review and a user update for
/// every single one, and anybody who had not updated would never see the new
/// video at all.
///
/// Held on the device after the first fetch, so the buttons still work with no
/// signal and the screens do not have to wait for the network to draw.
class VideoLinksStore extends ChangeNotifier {
  VideoLinksStore._();

  static final VideoLinksStore instance = VideoLinksStore._();

  static const String _prefsKey = 'help_video_links';

  Map<String, String> _links = <String, String>{};
  bool _loaded = false;

  /// Whether anything has been read yet, from disk or from the server.
  bool get loaded => _loaded;

  String linkFor(String key) => (_links[key] ?? '').trim();

  bool hasLink(String key) => linkFor(key).isNotEmpty;

  /// Reads what was saved last time, then refreshes from the server.
  ///
  /// The saved copy is applied first and on its own, so a screen opened with
  /// no signal still has the links it had yesterday. Called once at startup;
  /// the refresh is not awaited by anything on screen.
  Future<void> load({http.Client? client}) async {
    await _readCached();
    await refresh(client: client);
  }

  Future<void> _readCached() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        _apply(jsonDecode(raw));
      }
    } catch (_) {
      // A corrupt cache is the same as no cache.
    }
    _loaded = true;
    notifyListeners();
  }

  /// Pulls the current list. Safe to call whenever; failure changes nothing.
  Future<void> refresh({http.Client? client}) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response response = await httpClient
          .get(Uri.parse('${ApiConfig.baseUrl}/api/app/videos'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['ok'] == false) return;

      final Object? links = decoded['links'];
      if (links is! Map) return;

      _apply(links);
      _loaded = true;
      notifyListeners();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_links));
    } catch (_) {
      // Offline, or the server is having a moment. Whatever was cached stands;
      // a help button is never worth an error in front of someone.
    } finally {
      if (client == null) httpClient.close();
    }
  }

  void _apply(Object? raw) {
    if (raw is! Map) return;
    final Map<String, String> next = <String, String>{};
    raw.forEach((Object? key, Object? value) {
      if (key is String && value is String) next[key] = value.trim();
    });
    _links = next;
  }

  /// Tests only.
  @visibleForTesting
  void setLinksForTest(Map<String, String> links) {
    _links = Map<String, String>.from(links);
    _loaded = true;
    notifyListeners();
  }
}
