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
      final int revision = await _remote.save(overrides);
      // Recorded only once the server has taken it. A save that never landed
      // leaves the device on the older revision, so the next sync still sees
      // the server as behind and does not overwrite the change.
      await _store.save(overrides, revision: revision);
      return null;
    } on FormulaSyncException catch (error) {
      return error.message;
    }
  }

  /// Brings this device up to date with what the server holds.
  ///
  /// The server wins when it is newer, and only then. That is what lets a
  /// workshop ring up, read their formulas down the phone, and have them set
  /// from the office without touching anything themselves -- which the older
  /// rule could not do, because it only ever filled an empty device and so
  /// reached everyone except the people who had changed a formula and wanted
  /// it put right.
  ///
  /// A device that has changes the server has not accepted keeps them: its
  /// revision is unchanged, so the server is not newer and nothing is taken.
  /// The one case that does lose work is a formula saved here while offline
  /// and then set from the office before the phone reconnects -- and there the
  /// office is the later word, which is the answer that was wanted.
  Future<void> syncFromServer() async {
    final RemoteFormulas remote;
    try {
      remote = await _remote.fetch();
    } on FormulaSyncException {
      // No way to reach it. The device already holds what it needs.
      return;
    }

    final FormulaOverrides? incoming = remote.overrides;
    if (incoming == null) return;

    final int mine = await _store.revision();
    if (remote.revision <= mine) return;

    await _store.save(incoming, revision: remote.revision);
  }

  /// Forgets the catalogue, for tests.
  static void reset() {
    _catalogue = null;
    FormulaCatalogueAsset.reset();
  }
}
