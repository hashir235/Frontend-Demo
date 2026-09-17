import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/glass_color.dart';

/// The glass this shop picked last, wherever it was picked.
///
/// A new window and a new glass row both open on it, in any job, until
/// somebody picks something else. It used to come from the last window of the
/// job on screen, so every new job -- and every glass-only job -- opened on
/// clear again, and a shop that works in green mercury re-picked it at the
/// start of every single one.
///
/// Only a pick moves it. Opening an old window that happens to be glazed in
/// something else does not: that is looking at a past choice, not making one.
///
/// Read at startup, before the first screen, so the picker never opens on
/// clear and then jumps.
class LastGlassColor {
  LastGlassColor._();

  static final LastGlassColor instance = LastGlassColor._();

  static const String _prefsKey = 'quick_al.last_glass_color';

  String _value = GlassColors.initial;

  /// Always a glass on the rate list -- never blank, never a name that has
  /// since been dropped from it.
  String get value => _value;

  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _value = GlassColors.normalize(prefs.getString(_prefsKey));
    } catch (_) {
      // A phone that cannot read preferences still opens on clear.
      _value = GlassColors.initial;
    }
  }

  /// Takes [color] as the glass to open on from now on.
  ///
  /// Held in memory straight away, so the very next window gets it even if
  /// the write to the phone is still going.
  Future<void> remember(String color) async {
    final String next = GlassColors.normalize(color);
    _value = next;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next);
    } catch (_) {
      // The choice still holds for this run even if it could not be saved.
    }
  }

  @visibleForTesting
  void resetForTest() => _value = GlassColors.initial;
}
