import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/glass_color.dart';
import '../models/window_material.dart';
import '../models/window_review_item.dart';
import '../state/estimate_session_store.dart';
import '../state/last_glass_color.dart';
import '../state/last_window_material.dart';
import 'glass_color_picker.dart';
import 'window_material_picker.dart';

/// Gauge, aluminium and glass for every window at once, from the top of
/// Review (Hashir, Oct 2026).
///
/// Each opens a short list; a tap on one puts it on every window that comes
/// in it -- a job that was half 1.2mm and half 2mm is all one gauge after it,
/// except a window not made in that gauge, which keeps its own. Saved at once,
/// with an Undo for the times it was the wrong tap.
class ReviewApplyAllBar extends StatelessWidget {
  final EstimateSessionStore session;

  /// Writes the windows to the project. Throws when it could not.
  final Future<void> Function() save;

  const ReviewApplyAllBar({
    super.key,
    required this.session,
    required this.save,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Change for every window',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _ApplyButton(
                key: const Key('review_apply_gauge'),
                icon: Icons.straighten_rounded,
                label: 'Gauge',
                onTap: () => _pickGauge(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ApplyButton(
                key: const Key('review_apply_aluminium'),
                icon: Icons.palette_outlined,
                label: 'Aluminium',
                onTap: () => _pickAluminium(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ApplyButton(
                key: const Key('review_apply_glass'),
                icon: Icons.window_rounded,
                label: 'Glass',
                onTap: () => _pickGlass(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// "0.9mm" before "1.2mm" before "2mm": by thickness, not by spelling.
  static double _thickness(String gauge) =>
      double.tryParse(gauge.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  Future<void> _pickGauge(BuildContext context) async {
    final List<WindowReviewItem> items = session.items;
    final List<String> gauges =
        <String>{
          for (final WindowReviewItem item in items)
            ...WindowGauges.forWindow(item.windowCode),
        }.toList()..sort(
          (String a, String b) => _thickness(a).compareTo(_thickness(b)),
        );

    final String? picked = await _showChoices(
      context,
      title: 'Gauge for every window',
      note:
          'Every window that comes in it changes. One that does not keeps '
          'its own.',
      choices: <_Choice>[
        for (final String gauge in gauges)
          _choiceFor(
            items,
            value: gauge,
            label: gauge,
            leading: _GaugeBadge(gauge: gauge),
            takes: (WindowReviewItem item) =>
                WindowGauges.forWindow(item.windowCode).contains(gauge),
            isOn: (WindowReviewItem item) => item.material.gauge == gauge,
          ),
      ],
    );
    if (picked == null || !context.mounted) return;

    final List<WindowReviewItem> before = List<WindowReviewItem>.of(items);
    final int changed = session.setGaugeOnAll(picked);
    final int cannot = items
        .where(
          (WindowReviewItem item) =>
              !WindowGauges.forWindow(item.windowCode).contains(picked),
        )
        .length;
    if (WindowGauges.all.contains(picked)) {
      // The next new job opens on it too, as a gauge picked on a window does.
      unawaited(
        LastWindowMaterial.instance.remember(
          LastWindowMaterial.instance.value.copyWith(gauge: picked),
        ),
      );
    }
    final String rest = cannot == 0
        ? ''
        : ' ${_windows(cannot)} ${cannot == 1 ? 'does' : 'do'} not come in '
              '$picked and kept ${cannot == 1 ? 'its' : 'their'} own.';
    await _saveAndTell(
      context,
      before: before,
      changed: changed,
      message: changed == 0
          ? 'Every window that comes in $picked is already on it.$rest'
          : '$picked on ${_windows(changed)}.$rest',
    );
  }

  Future<void> _pickAluminium(BuildContext context) async {
    final List<WindowReviewItem> items = session.items;
    final String? picked = await _showChoices(
      context,
      title: 'Aluminium for every window',
      choices: <_Choice>[
        for (final String color in AluminiumColors.all)
          _choiceFor(
            items,
            value: color,
            label: AluminiumColors.labelFor(color),
            leading: AluminiumSwatch(color: color, size: 30),
            takes: (_) => true,
            isOn: (WindowReviewItem item) => item.material.color == color,
          ),
      ],
    );
    if (picked == null || !context.mounted) return;

    final List<WindowReviewItem> before = List<WindowReviewItem>.of(items);
    final int changed = session.setAluminiumColorOnAll(picked);
    unawaited(
      LastWindowMaterial.instance.remember(
        LastWindowMaterial.instance.value.copyWith(color: picked),
      ),
    );
    final String name = AluminiumColors.shortLabelFor(picked);
    await _saveAndTell(
      context,
      before: before,
      changed: changed,
      message: changed == 0
          ? 'Every window is already in $name.'
          : '$name aluminium on ${_windows(changed)}.',
    );
  }

  Future<void> _pickGlass(BuildContext context) async {
    final List<WindowReviewItem> items = session.items;
    final String? picked = await _showChoices(
      context,
      title: 'Glass for every window',
      choices: <_Choice>[
        for (final String glass in GlassColors.all)
          _choiceFor(
            items,
            value: glass,
            label: GlassColors.displayName(glass),
            leading: GlassSwatch(color: glass, size: 30),
            takes: (_) => true,
            isOn: (WindowReviewItem item) =>
                GlassColors.normalize(item.glassColor) == glass,
          ),
      ],
    );
    if (picked == null || !context.mounted) return;

    final List<WindowReviewItem> before = List<WindowReviewItem>.of(items);
    final int changed = session.setGlassOnAll(picked);
    unawaited(LastGlassColor.instance.remember(picked));
    final String name = GlassColors.displayName(picked);
    await _saveAndTell(
      context,
      before: before,
      changed: changed,
      message: changed == 0
          ? 'Every window is already glazed in $name.'
          : '$name glass on ${_windows(changed)}.',
    );
  }

  static String _windows(int count) =>
      count == 1 ? '1 window' : '$count windows';

  /// One line of a list: how many windows it is on now, and -- where not
  /// every window comes in it -- how many it would reach.
  static _Choice _choiceFor(
    List<WindowReviewItem> items, {
    required String value,
    required String label,
    required Widget leading,
    required bool Function(WindowReviewItem item) takes,
    required bool Function(WindowReviewItem item) isOn,
  }) {
    final int total = items.length;
    final int reach = items.where(takes).length;
    final int on = items.where(isOn).length;
    final List<String> bits = <String>[
      if (reach < total) 'For $reach of $total windows',
      on == 0
          ? 'On none now'
          : on == total
          ? 'On every window now'
          : 'On $on of $total now',
    ];
    return _Choice(
      value: value,
      label: label,
      leading: leading,
      detail: bits.join(' · '),
      isAllOn: on == total,
    );
  }

  Future<void> _saveAndTell(
    BuildContext context, {
    required List<WindowReviewItem> before,
    required int changed,
    required String message,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (changed == 0) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    try {
      await save();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Changed here, but not saved: $error')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            session.replaceItems(before);
            try {
              await save();
            } catch (error) {
              messenger.showSnackBar(
                SnackBar(content: Text('Put back here, but not saved: $error')),
              );
            }
          },
        ),
      ),
    );
  }

  static Future<String?> _showChoices(
    BuildContext context, {
    required String title,
    String? note,
    required List<_Choice> choices,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final TextTheme text = Theme.of(sheetContext).textTheme;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(note, style: text.bodySmall),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: <Widget>[
                      for (final _Choice choice in choices)
                        ListTile(
                          key: Key('apply_choice_${choice.value}'),
                          leading: choice.leading,
                          title: Text(
                            choice.label,
                            style: text.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(choice.detail),
                          trailing: choice.isAllOn
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.success,
                                )
                              : null,
                          onTap: () =>
                              Navigator.of(sheetContext).pop(choice.value),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Choice {
  final String value;
  final String label;
  final Widget leading;
  final String detail;
  final bool isAllOn;

  const _Choice({
    required this.value,
    required this.label,
    required this.leading,
    required this.detail,
    required this.isAllOn,
  });
}

/// One of the three buttons: icon over word, so all three fit side by side
/// on the narrowest phone.
class _ApplyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ApplyButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: AppTheme.royalBlue.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 20, color: AppTheme.royalBlue),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.royalBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gauge written in a small tile, in place of a swatch.
class _GaugeBadge extends StatelessWidget {
  final String gauge;

  const _GaugeBadge({required this.gauge});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.royalBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            gauge,
            style: const TextStyle(
              color: AppTheme.royalBlue,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
