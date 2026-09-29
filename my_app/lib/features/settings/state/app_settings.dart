import 'dart:async';

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
      _inputBlockOrder = prefs.getStringList(_inputBlockOrderKey);
      _numberingMode = _byName(
        NumberingMode.values,
        prefs.getString(_numberingModeKey),
        NumberingMode.auto,
      );
      _sizeInputMode = _byName(
        SizeInputMode.values,
        prefs.getString(_sizeInputModeKey),
        SizeInputMode.mergedKeypad,
      );
      _extraLengthUnit = prefs.getString(_extraLengthUnitKey);
      _customGlassSheet = prefs.getBool(_customGlassSheetKey) ?? false;
      _glassSheetWidthFt = prefs.getString(_glassSheetWidthKey) ?? '7';
      _glassSheetHeightFt = prefs.getString(_glassSheetHeightKey) ?? '12';
      _allowGlassRotation = prefs.getBool(_allowGlassRotationKey) ?? true;
    } catch (_) {
      // A phone that cannot read preferences still gets the usual boxes.
      resetForTest();
    }
    notifyListeners();
  }

  static const String _inputBlockOrderKey = 'quick_al.input_block_order';

  /// The order this phone's shop moved the input screen's parts into, or
  /// null for the screen as it came. The ids are `InputBlockOrder`'s.
  List<String>? _inputBlockOrder;

  List<String>? get inputBlockOrder => _inputBlockOrder;

  /// Keeps a new order, or with null goes back to the screen as it came.
  Future<void> setInputBlockOrder(List<String>? order) async {
    _inputBlockOrder = order == null ? null : List<String>.unmodifiable(order);
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (order == null) {
        await prefs.remove(_inputBlockOrderKey);
      } else {
        await prefs.setStringList(_inputBlockOrderKey, order);
      }
    } catch (_) {
      // The layout still holds for this run even if it could not be saved.
    }
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
  void resetForTest() {
    _perSideSizes = false;
    _inputBlockOrder = null;
    _numberingMode = NumberingMode.auto;
    _sizeInputMode = SizeInputMode.mergedKeypad;
    _extraLengthUnit = null;
    _customGlassSheet = false;
    _glassSheetWidthFt = '7';
    _glassSheetHeightFt = '12';
    _allowGlassRotation = true;
  }

  // Every choice below is kept on the phone the moment it is made and read
  // back at startup: a button stays where the shop left it until the shop
  // moves it again.

  static const String _numberingModeKey = 'quick_al.numbering_mode';
  static const String _sizeInputModeKey = 'quick_al.size_input_mode';
  static const String _extraLengthUnitKey = 'quick_al.recalc_extra_length_unit';
  static const String _customGlassSheetKey = 'quick_al.glass_sheet.custom';
  static const String _glassSheetWidthKey = 'quick_al.glass_sheet.width_ft';
  static const String _glassSheetHeightKey = 'quick_al.glass_sheet.height_ft';
  static const String _allowGlassRotationKey = 'quick_al.glass_sheet.rotation';

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  NumberingMode _numberingMode = NumberingMode.auto;

  NumberingMode get numberingMode => _numberingMode;

  void setNumberingMode(NumberingMode mode) {
    if (_numberingMode == mode) return;
    _numberingMode = mode;
    notifyListeners();
    _keep((SharedPreferences prefs) => prefs.setString(_numberingModeKey, mode.name));
  }

  SizeInputMode _sizeInputMode = SizeInputMode.mergedKeypad;

  SizeInputMode get sizeInputMode => _sizeInputMode;

  void setSizeInputMode(SizeInputMode mode) {
    if (_sizeInputMode == mode) return;
    _sizeInputMode = mode;
    notifyListeners();
    _keep((SharedPreferences prefs) => prefs.setString(_sizeInputModeKey, mode.name));
  }

  /// The unit Re Calculation's extra length was last typed in -- 'cm',
  /// 'inch' or 'feet' -- or null for the screen's own default.
  String? _extraLengthUnit;

  String? get extraLengthUnit => _extraLengthUnit;

  void setExtraLengthUnit(String unit) {
    if (_extraLengthUnit == unit) return;
    _extraLengthUnit = unit;
    _keep((SharedPreferences prefs) => prefs.setString(_extraLengthUnitKey, unit));
  }

  /// Glass layout: whether the shop cuts from a sheet of its own size, and
  /// that size in feet as it was typed.
  bool _customGlassSheet = false;
  String _glassSheetWidthFt = '7';
  String _glassSheetHeightFt = '12';

  bool get customGlassSheet => _customGlassSheet;
  String get glassSheetWidthFt => _glassSheetWidthFt;
  String get glassSheetHeightFt => _glassSheetHeightFt;

  void setCustomGlassSheet(bool value) {
    if (_customGlassSheet == value) return;
    _customGlassSheet = value;
    _keep((SharedPreferences prefs) => prefs.setBool(_customGlassSheetKey, value));
  }

  void setGlassSheetSize({required String widthFt, required String heightFt}) {
    if (_glassSheetWidthFt == widthFt && _glassSheetHeightFt == heightFt) return;
    _glassSheetWidthFt = widthFt;
    _glassSheetHeightFt = heightFt;
    _keep((SharedPreferences prefs) async {
      await prefs.setString(_glassSheetWidthKey, widthFt);
      await prefs.setString(_glassSheetHeightKey, heightFt);
      return true;
    });
  }

  /// Glass layout: whether a piece may be turned to fit the sheet.
  bool _allowGlassRotation = true;

  bool get allowGlassRotation => _allowGlassRotation;

  void setAllowGlassRotation(bool value) {
    if (_allowGlassRotation == value) return;
    _allowGlassRotation = value;
    _keep((SharedPreferences prefs) => prefs.setBool(_allowGlassRotationKey, value));
  }

  /// Writes a choice to the phone in the background. It already holds in
  /// memory, so the screen never waits on the write.
  void _keep(Future<bool> Function(SharedPreferences prefs) write) {
    unawaited(() async {
      try {
        await write(await SharedPreferences.getInstance());
      } catch (_) {
        // The choice still holds for this run even if it could not be saved.
      }
    }());
  }
}
