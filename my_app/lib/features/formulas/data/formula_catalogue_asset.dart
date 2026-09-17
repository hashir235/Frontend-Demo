/// Reading the shipped catalogue out of the app's own assets.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'formula_catalogue.dart';

/// Loads the catalogue the app was built with.
///
/// Kept apart from the catalogue itself so that everything which *uses*
/// formulas stays free of Flutter. That is not tidiness for its own sake: the
/// parity harness runs the app's real cutting code against the engine on five
/// hundred real jobs, and it can only do that outside a Flutter app if the
/// cutting code does not reach for an asset bundle.
class FormulaCatalogueAsset {
  const FormulaCatalogueAsset._();

  static const String path = 'assets/formulas/catalogue.json';

  static FormulaCatalogue? _loaded;
  static Future<FormulaCatalogue>? _loading;

  /// Reads the catalogue, once per run.
  ///
  /// It is a megabyte and a half of JSON and every window screen wants it, so
  /// a second caller arriving while the first is still reading waits on that
  /// read rather than starting another.
  static Future<FormulaCatalogue> load() {
    final FormulaCatalogue? already = _loaded;
    if (already != null) return Future<FormulaCatalogue>.value(already);
    return _loading ??= _read();
  }

  static Future<FormulaCatalogue> _read() async {
    final String source = await rootBundle.loadString(path);
    final FormulaCatalogue catalogue =
        FormulaCatalogue.fromJson(jsonDecode(source) as Map<String, dynamic>);
    _loaded = catalogue;
    _loading = null;
    return catalogue;
  }

  /// Forgets what was read, for tests that swap the bundle underneath.
  static void reset() {
    _loaded = null;
    _loading = null;
  }

  /// Hands the catalogue in, already read.
  ///
  /// For widget tests: reading an asset needs the real event loop, and a test
  /// that awaits one inside the fake clock waits for ever. A test reads the
  /// same file from disk and puts it here, so the screen under test finds it
  /// where it always looks.
  static void preload(FormulaCatalogue catalogue) {
    _loaded = catalogue;
    _loading = null;
  }
}
