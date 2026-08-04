import 'package:flutter/foundation.dart';

/// One line of the rate list: a section at a gauge, priced per colour.
///
/// The section carries its gauge in the name the way the trade writes it --
/// "D29 (1.2mm)" -- and the colours are whatever columns the owner's list
/// happens to have, so they are kept as a map rather than fixed fields.
@immutable
class RateRow {
  static const String sectionKey = 'SECTION';

  final String section;
  final Map<String, String> byColour;

  const RateRow({required this.section, required this.byColour});

  factory RateRow.fromJson(Map<String, dynamic> json) {
    final Map<String, String> colours = <String, String>{};
    for (final MapEntry<String, dynamic> e in json.entries) {
      if (e.key == sectionKey) continue;
      colours[e.key] = e.value?.toString().trim() ?? '';
    }
    return RateRow(
      section: (json[sectionKey] ?? '').toString().trim(),
      byColour: colours,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    sectionKey: section,
    ...byColour,
  };

  RateRow copyWith({String? section, Map<String, String>? byColour}) => RateRow(
    section: section ?? this.section,
    byColour: byColour ?? this.byColour,
  );

  /// Two sections are the same row if their names match ignoring case and
  /// spacing -- "D29 (1.2mm)" and "d29(1.2mm)" are one section, not two.
  static String normalizeSection(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
}

/// The whole list, plus whether this user has edited it.
@immutable
class RateList {
  final List<RateRow> rows;

  /// The owner's list, for showing what a value would go back to.
  final List<RateRow> master;

  /// True once the user has saved edits of their own.
  final bool customised;

  const RateList({
    required this.rows,
    required this.master,
    required this.customised,
  });

  static const RateList empty = RateList(
    rows: <RateRow>[],
    master: <RateRow>[],
    customised: false,
  );

  factory RateList.fromJson(Map<String, dynamic> json) {
    List<RateRow> parse(Object? raw) => (raw as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RateRow.fromJson)
        .where((RateRow r) => r.section.isNotEmpty)
        .toList(growable: false);

    return RateList(
      rows: parse(json['rates']),
      master: parse(json['master']),
      customised: json['customised'] == true,
    );
  }

  /// Every colour column present, in the order the owner's list defines them
  /// so a user's added row cannot reshuffle the table.
  List<String> get colours {
    final List<String> ordered = <String>[];
    for (final RateRow r in <RateRow>[...master, ...rows]) {
      for (final String c in r.byColour.keys) {
        if (!ordered.contains(c)) ordered.add(c);
      }
    }
    return ordered;
  }

  /// The owner's price for this section and colour, or null when the section
  /// is one the user added themselves.
  String? masterValue(String section, String colour) {
    final String key = RateRow.normalizeSection(section);
    for (final RateRow r in master) {
      if (RateRow.normalizeSection(r.section) == key) return r.byColour[colour];
    }
    return null;
  }

  bool hasSection(String section, {String? ignoring}) {
    final String key = RateRow.normalizeSection(section);
    final String? skip = ignoring == null
        ? null
        : RateRow.normalizeSection(ignoring);
    return rows.any(
      (RateRow r) =>
          RateRow.normalizeSection(r.section) == key &&
          RateRow.normalizeSection(r.section) != skip,
    );
  }
}
