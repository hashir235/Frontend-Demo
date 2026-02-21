import 'package:flutter/foundation.dart';

import 'numbering_mode.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._internal();

  static final AppSettings instance = AppSettings._internal();

  NumberingMode _numberingMode = NumberingMode.auto;

  NumberingMode get numberingMode => _numberingMode;

  void setNumberingMode(NumberingMode mode) {
    if (_numberingMode == mode) return;
    _numberingMode = mode;
    notifyListeners();
  }
}
