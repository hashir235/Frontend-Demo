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
  static const String _revisionKey = 'formula_overrides_revision_v1';

  /// The server revision this device last took a copy of.
  ///
  /// Zero for a phone that has never synced, which is also what a phone
  /// upgrading from a build that did not keep this reads -- and the right
  /// answer for both, since anything the server holds is then newer.
  Future<int> revision() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_revisionKey) ?? 0;
  }

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

  /// Writes the formulas, and the revision they came from when there is one.
  ///
  /// The formulas go down first. If the process dies between the two writes
  /// the device keeps the right formulas with a stale revision, which costs
  /// one redundant sync; the other order would keep the wrong formulas and
  /// call them current.
  Future<void> save(FormulaOverrides overrides, {int? revision}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(overrides.toJson()));
    if (revision != null) {
      await prefs.setInt(_revisionKey, revision);
    }
  }
}
