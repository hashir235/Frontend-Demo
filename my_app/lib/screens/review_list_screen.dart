import 'package:flutter/material.dart';

import '../data/window_catalog.dart';
import '../models/window_review_item.dart';
import '../models/window_type.dart';
import '../state/estimate_session_store.dart';
import '../theme/app_theme.dart';
import 'window_input_screen.dart';

class ReviewListScreen extends StatelessWidget {
  final EstimateSessionStore session;

  const ReviewListScreen({super.key, required this.session});

  Future<void> _editItem(BuildContext context, WindowReviewItem item) async {
    final WindowType? node = WindowCatalog.byDisplayIndex(item.windowIndex);
    if (node == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open editor for this item.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            WindowInputScreen(node: node, session: session, editingItem: item),
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, WindowReviewItem item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete item'),
          content: Text('Delete winNo ${item.winNo}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      session.deleteByWinNo(item.winNo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review'), centerTitle: true),
      body: AnimatedBuilder(
        animation: session,
        builder: (BuildContext context, Widget? child) {
          final List<WindowReviewItem> items = session.items;
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No saved windows yet.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.deepTeal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          return ListView.separated(
            key: const Key('review_list_view'),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final WindowReviewItem item = items[index];
              return Container(
                key: Key('review_item_${item.winNo}'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.sky.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.deepTeal.withValues(alpha: 0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'winNo ${item.winNo}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.deepTeal,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          key: Key('review_edit_${item.winNo}'),
                          onPressed: () => _editItem(context, item),
                          icon: const Icon(Icons.edit_outlined),
                          color: AppTheme.deepTeal,
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          key: Key('review_delete_${item.winNo}'),
                          onPressed: () => _deleteItem(context, item),
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: Colors.red.shade400,
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                    Text(
                      '${item.windowCode}  •  ${item.windowLabel}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Collar: ${item.collarIndex}   Unit: ${item.unitMode.label}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    Text(
                      'H: ${item.heightValue}   W: ${item.widthValue}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Description: ${item.description}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.deepTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
