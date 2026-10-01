import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  };
}

/// Which invoice figures this shop has switched off.
///
/// Everything prints until the shop taps a figure off. The choice is saved
/// the moment it is tapped and holds for every bill after, until the shop
/// taps it back on -- a shop that keeps its labour rate to itself keeps it
/// to itself on every job, not just this one.
///
/// Read at startup, before the first screen, like the other remembered
/// choices.
class InvoicePrintChoices extends ChangeNotifier {
  InvoicePrintChoices._();

  static final InvoicePrintChoices instance = InvoicePrintChoices._();

  static const String _key = 'quick_al.invoice_hidden_figures';

  Set<String> _hidden = <String>{};

  /// Whether [figure] goes on the PDF.
  bool prints(String figure) => !_hidden.contains(figure);

  /// The figures switched off, in a steady order, for the PDF request.
  List<String> get hidden => _hidden.toList()..sort();

  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _hidden = _known(prefs.getStringList(_key) ?? const <String>[]);
    } catch (_) {
      // A phone that cannot read preferences prints the full bill.
      _hidden = <String>{};
    }
    notifyListeners();
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
  /// leaves the figure off even if the write to the phone is still going.
  Future<void> _set(Set<String> next) async {
    _hidden = next;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, hidden);
    } catch (_) {
      // The choice still holds for this run even if it could not be saved.
    }
  }

  /// Names this version knows; one dropped since is not carried along.
  static Set<String> _known(Iterable<String> names) =>
      names.where(InvoiceFigure.all.contains).toSet();

  @visibleForTesting
  void resetForTest() => _hidden = <String>{};
}
