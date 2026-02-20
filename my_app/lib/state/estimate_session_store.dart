import 'package:flutter/foundation.dart';

import '../models/window_review_item.dart';
import 'numbering_mode.dart';

class EstimateSessionStore extends ChangeNotifier {
  final List<WindowReviewItem> _items = <WindowReviewItem>[];
  int _nextWinNo = 1;
  NumberingMode _numberingMode;

  EstimateSessionStore({NumberingMode numberingMode = NumberingMode.auto})
    : _numberingMode = numberingMode;

  List<WindowReviewItem> get items {
    final List<WindowReviewItem> sorted = List<WindowReviewItem>.from(_items);
    sorted.sort(
      (WindowReviewItem a, WindowReviewItem b) => a.winNo.compareTo(b.winNo),
    );
    return sorted;
  }

  int get nextWinNo => _nextWinNo;
  NumberingMode get numberingMode => _numberingMode;

  set numberingMode(NumberingMode mode) {
    if (_numberingMode == mode) {
      return;
    }
    _numberingMode = mode;
    notifyListeners();
  }

  bool existsWinNo(int winNo) {
    return _items.any((WindowReviewItem item) => item.winNo == winNo);
  }

  WindowReviewItem addItem({
    required int winNo,
    required String windowLabel,
    required String windowCode,
    required int windowIndex,
    required int collarIndex,
    required UnitMode unitMode,
    required String heightValue,
    required String widthValue,
    String? description,
  }) {
    final WindowReviewItem item = WindowReviewItem(
      winNo: winNo,
      windowLabel: windowLabel,
      windowCode: windowCode,
      windowIndex: windowIndex,
      collarIndex: collarIndex,
      unitMode: unitMode,
      heightValue: heightValue,
      widthValue: widthValue,
      description: description,
    );
    if (existsWinNo(winNo)) {
      throw ArgumentError('Window number already exists: $winNo');
    }

    _items.add(item);

    if (winNo >= _nextWinNo) {
      _nextWinNo = winNo + 1;
    } else if (_numberingMode == NumberingMode.auto) {
      _nextWinNo += 1;
    }
    notifyListeners();
    return item;
  }

  void updateItem(WindowReviewItem updated) {
    final int index = _items.indexWhere(
      (WindowReviewItem item) => item.winNo == updated.winNo,
    );
    if (index == -1) {
      return;
    }
    _items[index] = updated;
    notifyListeners();
  }

  void deleteByWinNo(int winNo) {
    _items.removeWhere((WindowReviewItem item) => item.winNo == winNo);
    notifyListeners();
  }
}
