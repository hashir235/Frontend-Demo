import 'package:flutter/foundation.dart';

import '../models/cost_table.dart';
import '../models/estimate_flow_state.dart';
import '../models/window_review_item.dart';
import '../models/window_material.dart';
import '../../settings/state/numbering_mode.dart';

/// Which kind of job a session belongs to.
///
/// Glass is its own flow, not fabrication with glass in it. It starts from
/// typed glass rows instead of from windows, so it never touches the window
/// library, and its projects are kept apart in history -- a glass job reopened
/// from history must land back on the row sheet, not in the window flow.
enum EstimateFlow { estimation, fabrication, glass }

class EstimateSessionStore extends ChangeNotifier {
  final String? projectId;
  final String projectName;
  final String projectLocation;
  final EstimateFlow flow;
  final List<WindowReviewItem> _items = <WindowReviewItem>[];
  int _nextWinNo = 1;
  NumberingMode _numberingMode;
  EstimateMaterialSelection? _materialSelection;
  List<RateOverrideInput> _rateOverrides = const <RateOverrideInput>[];
  EstimateBillDraft? _billDraft;

  EstimateSessionStore({
    this.projectId,
    required this.projectName,
    required this.projectLocation,
    this.flow = EstimateFlow.estimation,
    NumberingMode numberingMode = NumberingMode.auto,
  }) : _numberingMode = numberingMode;

  /// Aluminium fabrication. Deliberately false for [EstimateFlow.glass]: glass
  /// never runs the window pipeline, so anything gated on this stays off there.
  bool get isFabrication => flow == EstimateFlow.fabrication;

  bool get isGlass => flow == EstimateFlow.glass;

  List<WindowReviewItem> get items {
    final List<WindowReviewItem> sorted = List<WindowReviewItem>.from(_items);
    sorted.sort(
      (WindowReviewItem a, WindowReviewItem b) => a.winNo.compareTo(b.winNo),
    );
    return sorted;
  }

  int get nextWinNo => _nextWinNo;
  NumberingMode get numberingMode => _numberingMode;
  EstimateMaterialSelection? get materialSelection => _materialSelection;
  List<RateOverrideInput> get rateOverrides =>
      List<RateOverrideInput>.unmodifiable(_rateOverrides);
  EstimateBillDraft? get billDraft => _billDraft;

  void replaceItems(Iterable<WindowReviewItem> items) {
    _items
      ..clear()
      ..addAll(items);
    _syncNextWinNo();
    notifyListeners();
  }

  set numberingMode(NumberingMode mode) {
    if (_numberingMode == mode) {
      return;
    }
    _numberingMode = mode;
    notifyListeners();
  }

  void setMaterialSelection(EstimateMaterialSelection? selection) {
    final EstimateMaterialSelection? previous = _materialSelection;
    _materialSelection = selection;
    // When the user changes gauge or color (e.g. switching from 1.2 to 1.6),
    // any previously saved rate overrides and bill draft belong to the OLD
    // gauge — reusing them would silently apply 1.2 rates to a 1.6 bill.
    // Invalidate that cached state here so RateReviewScreen and BillInputs
    // load fresh values for the new selection.
    final bool selectionChanged =
        previous?.gaugeValue != selection?.gaugeValue ||
        previous?.colorValue != selection?.colorValue;
    if (selectionChanged) {
      _rateOverrides = const <RateOverrideInput>[];
      _billDraft = null;
    }
    notifyListeners();
  }

  void setRateOverrides(Iterable<RateOverrideInput> overrides) {
    _rateOverrides = List<RateOverrideInput>.from(overrides);
    notifyListeners();
  }

  void setBillDraft(EstimateBillDraft? draft) {
    _billDraft = draft;
    notifyListeners();
  }

  void restoreOutputs(Map<String, dynamic>? outputs) {
    _materialSelection = estimateMaterialSelectionFromProjectOutputs(outputs);
    _rateOverrides = estimateRateOverridesFromProjectOutputs(outputs);
    _billDraft = estimateBillDraftFromProjectOutputs(outputs);
    _adoptJobMaterialWhereUnset();
    notifyListeners();
  }

  /// Gives the windows of an older job the material that job was estimated at.
  ///
  /// Stock used to be one choice for a whole project, kept beside the job
  /// rather than on its windows. Reopening such a job leaves every window
  /// saying nothing, and defaulting those to champagne 1.2mm would quietly
  /// re-specify a job that was cut in 2mm black. The pair the job was actually
  /// estimated at is the one true answer available, so it is used.
  ///
  /// Windows saved since carry their own and are left alone.
  void _adoptJobMaterialWhereUnset() {
    final EstimateMaterialSelection? selection = _materialSelection;
    if (selection == null || !selection.isComplete) return;
    final WindowMaterial jobMaterial = WindowMaterial(
      gauge: selection.gaugeValue,
      color: selection.colorValue,
    );
    for (int i = 0; i < _items.length; i++) {
      final WindowReviewItem item = _items[i];
      if (item.material.isSet) continue;
      _items[i] = item.copyWith(material: item.material.orElse(jobMaterial));
    }
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
    double backCollarCm = kBackCollarDefaultCm,
    int? lockType,
    String? rubberType,
    String? description,
    WindowMaterial? material,
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
      backCollarCm: backCollarCm,
      lockType: lockType,
      rubberType: rubberType,
      description: description,
      material: material ?? materialForNextWindow,
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

  /// What the next window should start on: whatever the last one was entered
  /// in.
  ///
  /// A shop doing ten windows in 2mm black should say so once, not ten times.
  /// The exceptions -- the one door in a different colour -- are the windows
  /// where the fabricator is already thinking about it and will change it
  /// himself. Falls back to the opening default on the first window of a job.
  WindowMaterial get materialForNextWindow {
    if (_items.isEmpty) return WindowMaterial.initial;
    // The one entered last, not the lowest-numbered: that is the one whose
    // stock is still in mind.
    // orElse: a window from a job that was never estimated can still have no
    // material of its own, and the picker needs something to open on.
    return _items.last.material.orElse(WindowMaterial.initial);
  }

  /// One material to stand for the job, for the few places that still want a
  /// single pair.
  ///
  /// The engine prices each section from the window it came from, so this is
  /// never what a bar is costed at. It fills the job-wide field the request
  /// still carries -- which the engine uses only for windows that name no
  /// material of their own -- and seeds the rate screen's header. The first
  /// window's, because on the overwhelmingly common job every window shares
  /// it, and on a mixed job no single answer is right anyway.
  WindowMaterial get representativeMaterial {
    if (_items.isEmpty) return WindowMaterial.initial;
    return items.first.material.orElse(WindowMaterial.initial);
  }

  /// Every distinct material in the job, in the order first used.
  ///
  /// What the bill header shows instead of one gauge, and how a screen can
  /// tell at a glance whether this job is mixed at all.
  List<WindowMaterial> get materialsUsed {
    final List<WindowMaterial> out = <WindowMaterial>[];
    for (final WindowReviewItem item in items) {
      if (!out.contains(item.material)) out.add(item.material);
    }
    return out;
  }
}
