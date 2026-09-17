import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'numbering_mode.dart';
import 'size_input_mode.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._internal();

  static final AppSettings instance = AppSettings._internal();

  static const String _perSideKey = 'quick_al.per_side_sizes';

  /// Whether a window is measured one side at a time -- its top, its bottom
  /// and each jamb -- instead of one width and one height.
  ///
  /// Off unless a workshop turns it on. Most openings are square enough that
  /// four boxes would be three more than anybody wants to fill in; the shops
  /// that ask for this are the ones fitting into old walls, and for them it is
  /// the difference between a frame that goes in and one that has to be cut
  /// again.
  bool _perSideSizes = false;

  bool get perSideSizes => _perSideSizes;

  /// Reads what this phone was left on. Called once at startup: a setting that
  /// forgets itself every time the app opens is not a setting.
  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _perSideSizes = prefs.getBool(_perSideKey) ?? false;
    } catch (_) {
      // A phone that cannot read preferences still gets the usual boxes.
      _perSideSizes = false;
    }
    notifyListeners();
  }

  Future<void> setPerSideSizes(bool value) async {
    if (_perSideSizes == value) return;
    _perSideSizes = value;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_perSideKey, value);
    } catch (_) {
      // The choice still holds for this run even if it could not be saved.
    }
  }

  @visibleForTesting
  void resetForTest() => _perSideSizes = false;

  NumberingMode _numberingMode = NumberingMode.auto;

  NumberingMode get numberingMode => _numberingMode;

  void setNumberingMode(NumberingMode mode) {
    if (_numberingMode == mode) return;
    _numberingMode = mode;
    notifyListeners();
  }

  SizeInputMode _sizeInputMode = SizeInputMode.mergedKeypad;

  SizeInputMode get sizeInputMode => _sizeInputMode;

  void setSizeInputMode(SizeInputMode mode) {
    if (_sizeInputMode == mode) return;
    _sizeInputMode = mode;
    notifyListeners();
  }
}
