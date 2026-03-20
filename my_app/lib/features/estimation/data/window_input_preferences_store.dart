import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/window_review_item.dart';
import '../state/estimate_session_store.dart';

class WindowInputSidebarPreferences {
  final int? selectedCollar;
  final String? selectedSectionCode;
  final int? lockType;
  final String? rubberType;
  final bool? addBottom;
  final bool? addTee;
  final bool? addNet;

  const WindowInputSidebarPreferences({
    this.selectedCollar,
    this.selectedSectionCode,
    this.lockType,
    this.rubberType,
    this.addBottom,
    this.addTee,
    this.addNet,
  });

  factory WindowInputSidebarPreferences.fromJson(Map<String, dynamic> json) {
    return WindowInputSidebarPreferences(
      selectedCollar: _asInt(json['selectedCollar']),
      selectedSectionCode: _asString(json['selectedSectionCode']),
      lockType: _asInt(json['lockType']),
      rubberType: _asString(json['rubberType']),
      addBottom: _asBool(json['addBottom']),
      addTee: _asBool(json['addTee']),
      addNet: _asBool(json['addNet']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'selectedCollar': selectedCollar,
      'selectedSectionCode': selectedSectionCode,
      'lockType': lockType,
      'rubberType': rubberType,
      'addBottom': addBottom,
      'addTee': addTee,
      'addNet': addNet,
    };
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value');
  }

  static String? _asString(Object? value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value == null) {
      return null;
    }
    final String normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    return null;
  }
}

class WindowInputPreferencesStore {
  static const String _prefix = 'quick_al.window_input';

  String _flowKey(EstimateFlow flow) => flow.name;

  String _unitKey(EstimateFlow flow) => '$_prefix.unit.${_flowKey(flow)}';

  String _sidebarKey(EstimateFlow flow, String windowCode) =>
      '$_prefix.sidebar.${_flowKey(flow)}.${windowCode.trim()}';

  Future<UnitMode?> restoreUnitMode(EstimateFlow flow) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? raw = preferences.getString(_unitKey(flow));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return unitModeFromWireValue(raw);
  }

  Future<void> persistUnitMode(EstimateFlow flow, UnitMode unitMode) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_unitKey(flow), unitMode.wireValue);
  }

  Future<WindowInputSidebarPreferences?> restoreSidebar({
    required EstimateFlow flow,
    required String windowCode,
  }) async {
    if (windowCode.trim().isEmpty) {
      return null;
    }
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? raw = preferences.getString(_sidebarKey(flow, windowCode));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return WindowInputSidebarPreferences.fromJson(
        decoded.cast<String, dynamic>(),
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> persistSidebar({
    required EstimateFlow flow,
    required String windowCode,
    required WindowInputSidebarPreferences preferencesState,
  }) async {
    if (windowCode.trim().isEmpty) {
      return;
    }
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _sidebarKey(flow, windowCode),
      jsonEncode(preferencesState.toJson()),
    );
  }
}
