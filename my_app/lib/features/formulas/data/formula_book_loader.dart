/// Getting hold of the formulas in force, wherever they are needed.
library;

import '../model/formula_overrides.dart';
import 'formula_book.dart';
import 'formula_catalogue.dart';
import 'formula_catalogue_asset.dart';
import 'formula_overrides_store.dart';
import 'formula_sync_api_client.dart';

/// Loads the shipped formulas and this workshop's changes, and keeps them.
///
/// Two screens and every cutting run want the same book, and reading a
/// megabyte and a half of catalogue for each would be work done three times
/// for one answer.
///
/// A workshop's own changes live in two places on purpose. The device is the
/// one that must always answer, because a cutting list cannot wait on a
/// network and a shop with no signal still has metal to cut. The server is the
/// one that must not forget, because a new phone should not mean setting every
/// formula again. The device is read first and the server is caught up to
/// afterwards, so the slower of the two never holds up the saw.
class FormulaBookLoader {
  const FormulaBookLoader({
    FormulaOverridesStore store = const FormulaOverridesStore(),
    FormulaSyncApiClient? sync,
  })  : _store = store,
        _sync = sync;

  final FormulaOverridesStore _store;
  final FormulaSyncApiClient? _sync;

  FormulaSyncApiClient get _remote => _sync ?? FormulaSyncApiClient();

  static FormulaCatalogue? _catalogue;

  /// The formulas in force right now, from the device.
  Future<FormulaBook> load() async {
    final FormulaCatalogue catalogue = _catalogue ??= await FormulaCatalogueAsset.load();
    final FormulaOverrides overrides = await _store.load();
    return FormulaBook(catalogue, overrides);
  }

  /// Saves a workshop's changed formulas: to the device now, to the server
  /// when it can be reached.
  ///
  /// A save that reached the device is a save. Refusing it because the network
  /// was down would lose the change entirely, which is worse than holding it
  /// on one handset until the next sync -- so the server error is returned
  /// rather than thrown, for the caller to mention if it wants to.
  Future<String?> save(FormulaOverrides overrides) async {
    await _store.save(overrides);
    try {
      await _remote.save(overrides);
      return null;
    } on FormulaSyncException catch (error) {
      return error.message;
    }
  }

  /// Brings this device up to date with what the server holds.
  ///
  /// For a fresh install or a new phone, where the device has nothing and the
  /// server has everything. Only ever fills an empty device: a workshop that
  /// has changed a formula here and not yet synced it must not have it
  /// overwritten by an older copy.
  Future<void> restoreIfEmpty() async {
    final FormulaOverrides local = await _store.load();
    if (!local.isEmpty) return;
    try {
      final FormulaOverrides remote = await _remote.fetch();
      if (remote.isEmpty) return;
      await _store.save(remote);
    } on FormulaSyncException {
      // Nothing to restore from, or no way to reach it. The shipped formulas
      // are what a workshop starts on anyway.
    }
  }

  /// Forgets the catalogue, for tests.
  static void reset() {
    _catalogue = null;
    FormulaCatalogueAsset.reset();
  }
}
