import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../estimation/models/window_variant.dart';

/// Which bars a section is cut from.
enum SectionLengthGroup { even, odd, other }

/// The bar lengths of every section, as two groups instead of a box each.
///
/// Dealers stock a section in 14, 16 and 18 ft, or -- the collar sections --
/// in 15, 17 and 19. So rather than a line of typed-in lengths per section,
/// every section sits in one of two groups, and a tap moves it across: the
/// × on a section sends it to the other group, "Add" brings one in from it.
///
/// A section saved with lengths of its own (from before the groups) keeps
/// them, shown apart under "Other lengths", until it is moved into a group.
///
/// Works on the same controllers the screen saves from -- one per section,
/// holding its lengths as text -- so saving is unchanged.
class SectionLengthGroups extends StatelessWidget {
  const SectionLengthGroups({
    super.key,
    required this.controllers,
    required this.onChanged,
  });

  final Map<String, TextEditingController> controllers;

  /// Called after a section is moved, for the screen to redraw.
  final VoidCallback onChanged;

  static const List<int> evenLengths = <int>[14, 16, 18];
  static const List<int> oddLengths = <int>[15, 17, 19];

  /// Profiles a variant window cuts in place of a collar profile: ET30 and
  /// ET26 stand where M30F and M26F do, and are collar sections too.
  static final Set<String> _variantCollars = <String>{
    for (final WindowVariant variant in WindowVariants.all)
      for (final MapEntry<String, String> swap in variant.sections.entries)
        if (swap.key.endsWith('F')) swap.value,
  };

  /// Whether [section] is a collar section, bought in odd lengths: its name
  /// ends in F (DC30F, D54F, EC26F...), or it stands in for one that does.
  static bool isCollarSection(String section) {
    final String name = section.trim().toUpperCase();
    return name.endsWith('F') || _variantCollars.contains(name);
  }

  /// The group [lengths] put a section in.
  static SectionLengthGroup groupFor(List<int>? lengths) {
    if (lengths == null) return SectionLengthGroup.other;
    final Set<int> set = lengths.toSet();
    if (lengths.length == 3 && set.length == 3 && set.containsAll(evenLengths)) {
      return SectionLengthGroup.even;
    }
    if (lengths.length == 3 && set.length == 3 && set.containsAll(oddLengths)) {
      return SectionLengthGroup.odd;
    }
    return SectionLengthGroup.other;
  }

  static List<int>? _parse(String text) {
    final List<int> out = <int>[];
    for (final String part in text.split(',')) {
      final int? value = int.tryParse(part.trim());
      if (value == null) return null;
      out.add(value);
    }
    return out.isEmpty ? null : out;
  }

  SectionLengthGroup _groupOf(String section) =>
      groupFor(_parse(controllers[section]!.text));

  List<String> _sectionsIn(SectionLengthGroup group) {
    final List<String> out = <String>[
      for (final String section in controllers.keys)
        if (_groupOf(section) == group) section,
    ]..sort();
    return out;
  }

  void _move(String section, SectionLengthGroup to) {
    controllers[section]!.text =
        (to == SectionLengthGroup.odd ? oddLengths : evenLengths).join(', ');
    onChanged();
  }

  /// Collar sections to odd, the rest to even: the dealer's standard.
  void _restoreStandard(BuildContext context) {
    for (final String section in controllers.keys) {
      controllers[section]!.text =
          (isCollarSection(section) ? oddLengths : evenLengths).join(', ');
    }
    onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collar sections in Odd, the rest in Even. Save to apply.')),
    );
  }

  Future<void> _pickInto(BuildContext context, SectionLengthGroup group) async {
    final List<String> candidates = <String>[
      for (final String section in controllers.keys)
        if (_groupOf(section) != group) section,
    ]..sort();
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Add to ${group == SectionLengthGroup.odd ? 'Odd' : 'Even'} lengths',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  color: AppTheme.deepTeal,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (candidates.isEmpty)
                const Text('Every section is already in this group.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String section in candidates)
                      ActionChip(
                        key: Key('length_pick_$section'),
                        label: Text(section),
                        onPressed: () => Navigator.of(sheetContext).pop(section),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) _move(picked, group);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> others = _sectionsIn(SectionLengthGroup.other);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _restoreStandard(context),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Restore standard groups'),
          ),
        ),
        const SizedBox(height: 4),
        _GroupCard(
          key: const Key('length_group_even'),
          title: 'Even lengths',
          lengths: evenLengths,
          note: 'Plain sections',
          sections: _sectionsIn(SectionLengthGroup.even),
          onRemove: (String section) => _move(section, SectionLengthGroup.odd),
          onAdd: () => _pickInto(context, SectionLengthGroup.even),
          addKey: const Key('length_add_even'),
        ),
        const SizedBox(height: 12),
        _GroupCard(
          key: const Key('length_group_odd'),
          title: 'Odd lengths',
          lengths: oddLengths,
          note: 'Collar sections',
          sections: _sectionsIn(SectionLengthGroup.odd),
          onRemove: (String section) => _move(section, SectionLengthGroup.even),
          onAdd: () => _pickInto(context, SectionLengthGroup.odd),
          addKey: const Key('length_add_odd'),
        ),
        if (others.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _OtherCard(
            key: const Key('length_group_other'),
            sections: <String, String>{
              for (final String section in others) section: controllers[section]!.text,
            },
            onMove: _move,
          ),
        ],
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    super.key,
    required this.title,
    required this.lengths,
    required this.note,
    required this.sections,
    required this.onRemove,
    required this.onAdd,
    required this.addKey,
  });

  final String title;
  final List<int> lengths;
  final String note;
  final List<String> sections;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;
  final Key addKey;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      note,
                      style: text.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.deepTeal,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${lengths.join(' · ')} ft',
                  style: text.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String section in sections)
                InputChip(
                  key: Key('length_chip_$section'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  labelPadding: const EdgeInsets.only(left: 6, right: 2),
                  label: Text(section, style: const TextStyle(fontSize: 13)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  deleteButtonTooltipMessage: 'Move out of $title',
                  onDeleted: () => onRemove(section),
                ),
              ActionChip(
                key: addKey,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                onPressed: onAdd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sections saved with lengths of their own, kept as they are until moved.
class _OtherCard extends StatelessWidget {
  const _OtherCard({super.key, required this.sections, required this.onMove});

  /// Section -> its lengths as saved.
  final Map<String, String> sections;
  final void Function(String section, SectionLengthGroup to) onMove;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Other lengths',
            style: text.titleMedium?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Saved with lengths of their own. Tap one to put it in a group.',
            style: text.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final MapEntry<String, String> entry in sections.entries)
                PopupMenuButton<SectionLengthGroup>(
                  key: Key('length_chip_${entry.key}'),
                  onSelected: (SectionLengthGroup to) => onMove(entry.key, to),
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<SectionLengthGroup>>[
                    PopupMenuItem<SectionLengthGroup>(
                      value: SectionLengthGroup.even,
                      child: Text('Even: 14 · 16 · 18 ft'),
                    ),
                    PopupMenuItem<SectionLengthGroup>(
                      value: SectionLengthGroup.odd,
                      child: Text('Odd: 15 · 17 · 19 ft'),
                    ),
                  ],
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
