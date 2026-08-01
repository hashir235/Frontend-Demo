import 'package:flutter/foundation.dart';

import 'numbering_mode.dart';
import 'size_input_mode.dart';

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

  SizeInputMode _sizeInputMode = SizeInputMode.wheel;

  SizeInputMode get sizeInputMode => _sizeInputMode;

  void setSizeInputMode(SizeInputMode mode) {
    if (_sizeInputMode == mode) return;
    _sizeInputMode = mode;
    notifyListeners();
  }
}
