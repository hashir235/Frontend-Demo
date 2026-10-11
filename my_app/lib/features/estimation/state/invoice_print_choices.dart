import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/data/bill_defaults_api_client.dart';

/// The figures on the invoice PDF that a shop can keep off it.
///
/// A shop does not always want its customer to see every rate and cost, so
/// on the Final Bill screen each figure that prints is a switch. Each name is
/// one cost line, one total, or one column of a table: a column goes for
/// every row at once, the way it reads on the screen.
///
/// The server and InvoicePDF.py know these same names (HIDEABLE_FIGURES) and
/// ignore anything else.
abstract final class InvoiceFigure {
  static const String windowQuantity = 'windows.quantity';
  static const String windowArea = 'windows.area';
  static const String windowHardwareRate = 'windows.hardwareRate';
  static const String windowHardwareCost = 'windows.hardwareCost';

  static const String glassArea = 'glass.area';
  static const String glassRate = 'glass.rate';
  static const String glassCost = 'glass.cost';

  static const String totalGlassCost = 'totals.glassCost';
  static const String totalLaborCost = 'totals.laborCost';
  static const String totalHardwareCost = 'totals.hardwareCost';
  static const String aluminiumOriginal = 'totals.aluminiumOriginal';
  static const String aluminiumDiscount = 'totals.aluminiumDiscount';
  static const String aluminiumAfterDiscount = 'totals.aluminiumAfterDiscount';
  static const String extraCharges = 'totals.extraCharges';
  static const String advancePaid = 'totals.advancePaid';
  static const String grandTotal = 'totals.grandTotal';
  static const String remainingDue = 'totals.remainingDue';

  /// Grand Total over the job's feet: the last line of Cost Breakdown.
  static const String netAmountPerArea = 'totals.netAmountPerArea';

  static const Set<String> all = <String>{
    windowQuantity,
    windowArea,
    windowHardwareRate,
    windowHardwareCost,
    glassArea,
    glassRate,
    glassCost,
    totalGlassCost,
    totalLaborCost,
    totalHardwareCost,
    aluminiumOriginal,
    aluminiumDiscount,
    aluminiumAfterDiscount,
    extraCharges,
    advancePaid,
    grandTotal,
    remainingDue,
    netAmountPerArea,
  };
}

/// Which invoice figures this shop has switched off.
///
/// Everything prints until the shop taps a figure off. The choice is saved
/// the moment it is tapped and holds for every bill after, until the shop
/// taps it back on -- a shop that keeps its labour rate to itself keeps it
/// to itself on every job, not just this one.
///
/// Kept with the account as well as on the phone (Hashir, Oct 2026), so the
/// choices follow the shop to a new phone or a reinstall, and one shop's do
/// not reach the next account signed in on the same phone:
///
///  * a tap is held on the phone at once and sent to the account;
///  * a tap that could not be sent (no signal) is marked unsent, and goes up
///    at the next chance -- it is newer than anything the account holds;
///  * on signing in, and when the Final Bill opens, the account's choices
///    are taken; an account that has never had them gets this phone's;
///  * signing out clears them from the phone.
///
/// Read at startup, before the first screen, like the other remembered
/// choices.
class InvoicePrintChoices extends ChangeNotifier {
  InvoicePrintChoices._();

  static final InvoicePrintChoices instance = InvoicePrintChoices._();

  static const String _key = 'quick_al.invoice_hidden_figures';

  /// Set while a choice made on this phone has not reached the account yet.
  static const String _unsentKey = 'quick_al.invoice_hidden_figures_unsent';

  /// How the account is reached. Swapped in tests.
  @visibleForTesting
  BillDefaultsApiClient Function() clientFactory = BillDefaultsApiClient.new;

  Set<String> _hidden = <String>{};
  bool _unsent = false;

  /// Moved on by every change made here, so an answer from the account that
  /// was asked for before a tap never undoes the tap.
  int _generation = 0;

  /// Whether [figure] goes on the PDF.
  bool prints(String figure) => !_hidden.contains(figure);

  /// The figures switched off, in a steady order, for the PDF request.
  List<String> get hidden => _hidden.toList()..sort();

  /// Whether a choice made on this phone is still to reach the account.
  bool get isUnsent => _unsent;

  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _hidden = _known(prefs.getStringList(_key) ?? const <String>[]);
      _unsent = prefs.getBool(_unsentKey) ?? false;
    } catch (_) {
      // A phone that cannot read preferences prints the full bill.
      _hidden = <String>{};
      _unsent = false;
    }
    notifyListeners();
  }

  /// Brings this phone and the account into step. Called after signing in
  /// and when the Final Bill opens; never fails -- without a connection the
  /// phone's choices simply hold until the next time.
  Future<void> syncWithAccount() async {
    if (_unsent) {
      await _send();
      return;
    }
    final int asked = _generation;
    final List<String>? saved;
    try {
      saved = (await clientFactory().fetch()).invoicePrintHidden;
    } catch (_) {
      return;
    }
    if (asked != _generation) return; // tapped meanwhile: the tap stands
    if (saved == null) {
      // Never saved with this account: this phone's choices, made before
      // they were kept with the account, go up as they are.
      if (_hidden.isNotEmpty) {
        _unsent = true;
        await _send();
      }
      return;
    }
    final Set<String> theirs = _known(saved);
    if (setEquals(theirs, _hidden)) return;
    _hidden = theirs;
    notifyListeners();
    await _writeLocal();
  }

  /// Signing out: the next account on this phone starts on its own choices,
  /// not this one's.
  Future<void> clearForSignOut() async {
    _generation++;
    _hidden = <String>{};
    _unsent = false;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_unsentKey);
    } catch (_) {
      // Cleared in memory; the phone's copy goes the next time it can.
    }
  }

  /// Switches [figure] off if it prints, on if it does not.
  Future<void> toggle(String figure) {
    if (!InvoiceFigure.all.contains(figure)) {
      return Future<void>.value();
    }
    final Set<String> next = Set<String>.of(_hidden);
    if (!next.remove(figure)) {
      next.add(figure);
    }
    return _set(next);
  }

  /// Every figure back on the PDF.
  Future<void> printAll() => _set(<String>{});

  /// Held in memory straight away, so a PDF asked for a moment later already
  /// leaves the figure off even if the write to the phone is still going;
  /// then kept on the phone, and sent to the account.
  Future<void> _set(Set<String> next) async {
    _generation++;
    _hidden = next;
    _unsent = true;
    notifyListeners();
    await _writeLocal();
    await _send();
  }

  /// Sends this phone's choices to the account. Marked sent only if nothing
  /// was tapped while they were on their way.
  Future<void> _send() async {
    final int sending = _generation;
    try {
      await clientFactory().setInvoicePrintHidden(hidden);
    } catch (_) {
      return; // still unsent: it goes up with the next sync
    }
    if (sending != _generation) return;
    _unsent = false;
    await _writeLocal();
  }

  Future<void> _writeLocal() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, hidden);
      await prefs.setBool(_unsentKey, _unsent);
    } catch (_) {
      // The choice still holds for this run even if it could not be saved.
    }
  }

  /// Names this version knows; one dropped since is not carried along.
  static Set<String> _known(Iterable<String> names) =>
      names.where(InvoiceFigure.all.contains).toSet();

  @visibleForTesting
  void resetForTest() {
    _hidden = <String>{};
    _unsent = false;
    _generation = 0;
  }
}
