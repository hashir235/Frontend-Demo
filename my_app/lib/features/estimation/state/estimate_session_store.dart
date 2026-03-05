import 'package:flutter/foundation.dart';

import '../models/window_review_item.dart';
import '../../settings/state/numbering_mode.dart';

class EstimateSessionStore extends ChangeNotifier {
  final String projectName;
  final String projectLocation;
  final List<WindowReviewItem> _items = <WindowReviewItem>[];
  int _nextWinNo = 1;
  NumberingMode _numberingMode;

  EstimateSessionStore({
    required this.projectName,
    required this.projectLocation,
    NumberingMode numberingMode = NumberingMode.auto,
  }) : _numberingMode = numberingMode;

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

  void _syncNextWinNo() {
    int highest = 0;
    for (final WindowReviewItem item in _items) {
      if (item.winNo > highest) {
        highest = item.winNo;
      }
    }
    _nextWinNo = highest + 1;
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
    String? rightWidthValue,
    String? leftWidthValue,
    String? archValue,
    bool addBottom = false,
    bool addTee = false,
    bool addNet = false,
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
      rightWidthValue: rightWidthValue,
      leftWidthValue: leftWidthValue,
      archValue: archValue,
      addBottom: addBottom,
      addTee: addTee,
      addNet: addNet,
      description: description,
    );
    if (existsWinNo(winNo)) {
      throw ArgumentError('Window number already exists: $winNo');
    }

    _items.add(item);
    _syncNextWinNo();
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
    _syncNextWinNo();
    notifyListeners();
  }
}
