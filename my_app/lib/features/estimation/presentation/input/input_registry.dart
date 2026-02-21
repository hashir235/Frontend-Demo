import 'package:flutter/material.dart';

import '../../models/window_type.dart';
import '../../state/estimate_session_store.dart';
import '../../models/window_review_item.dart';
import 'window_input_base.dart';
import 'sliding_window_input.dart';
import 'sliding_window_m_section_input.dart';
import 'panel_windows_input.dart';
import 'panel_windows_m_section_input.dart';
import 'sliding_corner_windows_input.dart';
import 'sliding_corner_windows_m_section_input.dart';
import 'fix_window_input.dart';
import 'corner_fix_input.dart';
import 'openable_input.dart';
import 'door_single_input.dart';
import 'door_double_input.dart';
import 'arch_round_input.dart';
import 'arch_rect_input.dart';

Widget buildInputScreen({
  required WindowType node,
  required EstimateSessionStore session,
  WindowReviewItem? editingItem,
}) {
  final String? code = node.codeName;
  switch (code) {
    case 'S_win':
      return SlidingWindowInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'MS_win':
      return SlidingWindowMSectionInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'PF3_win':
    case 'PS4_win':
    case 'EF3_win':
    case 'ES3_win':
      return PanelWindowsInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'MPF3_win':
    case 'MPS4_win':
    case 'MEF3_win':
    case 'MES3_win':
      return PanelWindowsMSectionInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'SCF_win':
    case 'SCS_win':
    case 'SCL_win':
    case 'SCR_win':
      return SlidingCornerWindowsInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'MSCF_win':
    case 'MSCS_win':
    case 'MSCL_win':
    case 'MSCR_win':
      return SlidingCornerWindowsMSectionInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'F_win':
      return FixWindowInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'FC_win':
      return CornerFixInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'O_win':
      return OpenableInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'Single_Door':
      return DoorSingleInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'Double_Door':
      return DoorDoubleInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'A_win':
      return ArchRoundInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    case 'AR_win':
      return ArchRectInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
    default:
      return WindowInputScreen(
        node: node,
        session: session,
        editingItem: editingItem,
      );
  }
}
