/// Keeping a workshop's changed formulas on the device.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/formula_overrides.dart';

/// Keeps a workshop's changed formulas on the device.
///
/// The device is not where they belong in the end -- a formula has to survive
/// a reinstall and be readable from the office -- but it is where they have to
/// be readable instantly, because every window screen needs them and a cutting
/// list cannot wait on a network.
class FormulaOverridesStore {
  const FormulaOverridesStore();

  static const String _key = 'formula_overrides_v1';

  Future<FormulaOverrides> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return FormulaOverrides.empty();
    try {
      return FormulaOverrides.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      // Unreadable rather than absent. Falling back to the shipped formulas is
      // the safe way to be wrong: a workshop notices their change has gone and
      // makes it again, where a half-parsed formula would cut metal quietly.
      return FormulaOverrides.empty();
    }
  }

  Future<void> save(FormulaOverrides overrides) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(overrides.toJson()));
  }
}
