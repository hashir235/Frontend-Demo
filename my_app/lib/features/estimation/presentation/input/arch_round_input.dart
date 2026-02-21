import 'package:flutter/material.dart';

import '../../models/window_review_item.dart';
import '../../models/window_type.dart';
import '../../state/estimate_session_store.dart';
import 'window_input_base.dart';

class ArchRoundInputScreen extends StatelessWidget {
  final WindowType node;
  final EstimateSessionStore session;
  final WindowReviewItem? editingItem;

  const ArchRoundInputScreen({
    super.key,
    required this.node,
    required this.session,
    this.editingItem,
  });

  @override
  Widget build(BuildContext context) {
    return WindowInputScreen(
      node: node,
      session: session,
      editingItem: editingItem,
    );
  }
}
