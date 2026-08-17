import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// What the user picked in Settings.
enum AppThemeMode { system, light, dark }

extension AppThemeModeLabel on AppThemeMode {
  String get label => switch (this) {
    AppThemeMode.system => 'Match phone',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };

  String get description => switch (this) {
    AppThemeMode.system => 'Follows your phone\'s own light or dark setting.',
    AppThemeMode.light => 'Always light, whatever the phone is set to.',
    AppThemeMode.dark => 'Always dark. Easier on the eyes at night.',
  };

  IconData get icon => switch (this) {
    AppThemeMode.system => Icons.brightness_auto_rounded,
    AppThemeMode.light => Icons.light_mode_rounded,
    AppThemeMode.dark => Icons.dark_mode_rounded,
  };

  String get _stored => name;
}

/// Holds the chosen theme and rebuilds the app when it changes.
///
/// The palette lives as one global on [AppTheme] because the whole app reads
/// its colours by name, so this controller's job is to set that global
/// *before* the app rebuilds -- not to hand Flutter two themes and let it
/// choose, which would leave the global and the ThemeData disagreeing.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _prefsKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.system;
  AppThemeMode get mode => _mode;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Whether the app should currently be dark, resolving "match phone".
  bool get isDark => switch (_mode) {
    AppThemeMode.light => false,
    AppThemeMode.dark => true,
    AppThemeMode.system =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark,
  };

  /// Reads the saved choice and applies it. Called once at startup, before the
  /// first frame, so nobody sees a flash of the wrong colours.
  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_prefsKey);
      if (saved != null) {
        _mode = AppThemeMode.values.firstWhere(
          (AppThemeMode m) => m._stored == saved,
          orElse: () => AppThemeMode.system,
        );
      }
    } catch (_) {
      // A phone that cannot read preferences still gets a working app.
    }
    _loaded = true;
    _apply();
    // "Match phone" has to keep matching -- the phone can switch to dark at
    // sunset while the app is open.
    PlatformDispatcher.instance.onPlatformBrightnessChanged = () {
      if (_mode == AppThemeMode.system) {
        _apply();
        notifyListeners();
      }
    };
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    _apply();
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode._stored);
    } catch (_) {
      // The choice still holds for this run even if it could not be saved.
    }
  }

  void _apply() => AppTheme.isDark = isDark;
}
