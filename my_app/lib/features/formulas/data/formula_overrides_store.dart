/// The formulas a workshop has changed for itself.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/formula_window_key.dart';

/// Which piece a changed formula belongs to.
///
/// Position rather than name, because two pieces in one profile can share a
/// label -- a sliding window takes two M23 uprights, both called H -- and a
/// workshop that shortens one has not asked to shorten the other.
class FormulaPieceRef {
  const FormulaPieceRef({
    required this.windowKey,
    required this.configKey,
    required this.section,
    required this.index,
  });

  final String windowKey;
  final String configKey;
  final String section;
  final int index;

  factory FormulaPieceRef.of(FormulaWindowKey key, String section, int index) {
    return FormulaPieceRef(
      windowKey: key.windowKey,
      configKey: key.configKey,
      section: section,
      index: index,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FormulaPieceRef &&
      other.windowKey == windowKey &&
      other.configKey == configKey &&
      other.section == section &&
      other.index == index;

  @override
  int get hashCode => Object.hash(windowKey, configKey, section, index);

  @override
  String toString() => '$windowKey [$configKey] $section#$index';
}

/// Every formula a workshop has changed, and nothing else.
///
/// Kept apart from the shipped catalogue on purpose. A workshop changes a
/// handful of sums at most, and holding only those means "reset" always has
/// something true to go back to, an update to the shipped formulas reaches
/// every piece nobody has touched, and what a workshop actually decided for
/// itself is a short, readable list rather than eighteen thousand rows.
///
/// Stored nested -- window, then configuration, then profile, then position --
/// rather than under one joined-up key. Joining would need a separator that
/// none of those four can contain, and window keys already carry `/`,
/// configuration keys `=` and `|`. Nesting needs no such promise, and what
/// lands in storage can be read.
class FormulaOverrides {
  FormulaOverrides._(this._byPiece);

  factory FormulaOverrides.empty() => FormulaOverrides._(<FormulaPieceRef, String>{});

  final Map<FormulaPieceRef, String> _byPiece;

  bool get isEmpty => _byPiece.isEmpty;
  int get count => _byPiece.length;

  /// Every changed piece, for showing what a workshop has altered and for
  /// sending it to the server.
  Map<FormulaPieceRef, String> get all =>
      Map<FormulaPieceRef, String>.unmodifiable(_byPiece);

  /// The workshop's formula for this piece, or null if they have not changed
  /// it and the shipped one stands.
  String? formulaFor(FormulaPieceRef ref) => _byPiece[ref];

  bool hasChanged(FormulaPieceRef ref) => _byPiece.containsKey(ref);

  void set(FormulaPieceRef ref, String storedFormula) {
    _byPiece[ref] = storedFormula;
  }

  /// Puts a piece back to what Quick AL ships.
  void clear(FormulaPieceRef ref) {
    _byPiece.remove(ref);
  }

  /// Puts every piece of one window configuration back.
  void clearConfig(FormulaWindowKey key) {
    _byPiece.removeWhere((FormulaPieceRef ref, String _) =>
        ref.windowKey == key.windowKey && ref.configKey == key.configKey);
  }

  /// Whether anything in this window configuration has been changed.
  bool configHasChanges(FormulaWindowKey key) {
    return _byPiece.keys.any((FormulaPieceRef ref) =>
        ref.windowKey == key.windowKey && ref.configKey == key.configKey);
  }

  /// Every place the shipped catalogue holds this same piece, so a change can
  /// be offered to all of them at once. The caller decides whether to take it.
  Iterable<FormulaPieceRef> get refs => _byPiece.keys;

  FormulaOverrides copy() => FormulaOverrides._(Map<FormulaPieceRef, String>.from(_byPiece));

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> windows = <String, dynamic>{};
    _byPiece.forEach((FormulaPieceRef ref, String formula) {
      final Map<String, dynamic> configs =
          windows.putIfAbsent(ref.windowKey, () => <String, dynamic>{}) as Map<String, dynamic>;
      final Map<String, dynamic> sections =
          configs.putIfAbsent(ref.configKey, () => <String, dynamic>{}) as Map<String, dynamic>;
      final Map<String, dynamic> pieces =
          sections.putIfAbsent(ref.section, () => <String, dynamic>{}) as Map<String, dynamic>;
      pieces['${ref.index}'] = formula;
    });
    return <String, dynamic>{'version': 1, 'windows': windows};
  }

  static FormulaOverrides fromJson(Map<String, dynamic>? json) {
    final Map<FormulaPieceRef, String> parsed = <FormulaPieceRef, String>{};
    final Object? windows = json?['windows'];
    if (windows is! Map) return FormulaOverrides._(parsed);

    windows.forEach((Object? windowKey, Object? configs) {
      if (windowKey is! String || configs is! Map) return;
      configs.forEach((Object? configKey, Object? sections) {
        if (configKey is! String || sections is! Map) return;
        sections.forEach((Object? section, Object? pieces) {
          if (section is! String || pieces is! Map) return;
          pieces.forEach((Object? index, Object? formula) {
            if (index is! String || formula is! String) return;
            final int? position = int.tryParse(index);
            if (position == null) return;
            parsed[FormulaPieceRef(
              windowKey: windowKey,
              configKey: configKey,
              section: section,
              index: position,
            )] = formula;
          });
        });
      });
    });

    return FormulaOverrides._(parsed);
  }
}

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
