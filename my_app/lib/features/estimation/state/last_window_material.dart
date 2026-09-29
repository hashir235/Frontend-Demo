import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/window_material.dart';

/// The gauge and colour this shop picked last, wherever it was picked.
///
/// The first window of a new job opens on it, until somebody picks something
/// else -- the way [LastGlassColor] does for glass. It used to open on 1.2mm
/// champagne every time, so a shop that works in 2mm black re-picked both at
/// the start of every job.
///
/// Only a pick moves it. Opening an old window in some other stock does not:
/// that is looking at a past choice, not making one.
///
/// Read at startup, before the first screen, so the picker never opens on the
/// default and then jumps.
class LastWindowMaterial {
  LastWindowMaterial._();

  static final LastWindowMaterial instance = LastWindowMaterial._();

  static const String _gaugeKey = 'quick_al.last_window_gauge';
  static const String _colorKey = 'quick_al.last_window_color';

  WindowMaterial _value = WindowMaterial.initial;

  /// Always a gauge and a colour on the rate list.
  WindowMaterial get value => _value;

  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _value = _normalized(
        WindowMaterial(
          gauge: prefs.getString(_gaugeKey) ?? '',
          color: prefs.getString(_colorKey) ?? '',
        ),
      );
    } catch (_) {
      // A phone that cannot read preferences still opens on the default.
      _value = WindowMaterial.initial;
    }
  }

  /// Takes [material] as the stock to open on from now on.
  ///
  /// Held in memory straight away, so the very next window gets it even if
  /// the write to the phone is still going.
  Future<void> remember(WindowMaterial material) async {
    final WindowMaterial next = _normalized(material);
    _value = next;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_gaugeKey, next.gauge);
      await prefs.setString(_colorKey, next.color);
    } catch (_) {
      // The choice still holds for this run even if it could not be saved.
    }
  }

  /// [material] with anything not on the rate list put back to the default:
  /// a gauge or colour since dropped must not price a job at nothing.
  static WindowMaterial _normalized(WindowMaterial material) {
    return WindowMaterial(
      gauge: WindowGauges.all.contains(material.gauge)
          ? material.gauge
          : WindowMaterial.initial.gauge,
      color: AluminiumColors.normalize(material.color),
    );
  }

  @visibleForTesting
  void resetForTest() => _value = WindowMaterial.initial;
}
