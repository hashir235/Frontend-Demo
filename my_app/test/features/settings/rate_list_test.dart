import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/settings/models/rate_list.dart';

/// Rates differ by city, so each workshop edits its own copy of the owner's
/// list. Two rows for one section would make the price depend on whichever the
/// engine read first, so adding a duplicate has to be refused.
void main() {
  RateList listWith(List<String> sections) => RateList(
    rows: sections
        .map(
          (String s) => RateRow(
            section: s,
            byColour: const <String, String>{'DULL': '100'},
          ),
        )
        .toList(),
    master: const <RateRow>[],
    customised: false,
  );

  group('duplicate sections', () {
    test('an exact repeat is caught', () {
      expect(listWith(<String>['D29 (1.2mm)']).hasSection('D29 (1.2mm)'), isTrue);
    });

    test('case and spacing do not smuggle one past', () {
      final RateList list = listWith(<String>['D29 (1.2mm)']);
      expect(list.hasSection('d29 (1.2mm)'), isTrue);
      expect(list.hasSection('D29(1.2MM)'), isTrue);
      expect(list.hasSection('  D29 (1.2mm)  '), isTrue);
    });

    test('a different gauge is a different section', () {
      expect(listWith(<String>['D29 (1.2mm)']).hasSection('D29 (1.6mm)'), isFalse);
    });

    test('a genuinely new section is allowed', () {
      expect(listWith(<String>['D29 (1.2mm)']).hasSection('D33 (2mm)'), isFalse);
    });
  });

  group('reading the server payload', () {
    final RateList list = RateList.fromJson(<String, dynamic>{
      'rates': <dynamic>[
        <String, dynamic>{
          'SECTION': 'D29 (1.2mm)',
          'DULL': '280',
          'BLACK/ MULTI': '307',
        },
      ],
      'master': <dynamic>[
        <String, dynamic>{
          'SECTION': 'D29 (1.2mm)',
          'DULL': '273',
          'BLACK/ MULTI': '307',
        },
      ],
      'customised': true,
    });

    test('the edited value is the one in force', () {
      expect(list.rows.single.byColour['DULL'], '280');
      expect(list.customised, isTrue);
    });

    test('the standard value stays available to reset back to', () {
      expect(list.masterValue('D29 (1.2mm)', 'DULL'), '273');
    });

    test('a section the user invented has no standard value', () {
      expect(list.masterValue('D99 (1.2mm)', 'DULL'), isNull);
    });

    test('colour columns follow the owner list order', () {
      expect(list.colours, <String>['DULL', 'BLACK/ MULTI']);
    });

    test('rows without a section name are dropped', () {
      final RateList bad = RateList.fromJson(<String, dynamic>{
        'rates': <dynamic>[
          <String, dynamic>{'SECTION': '', 'DULL': '1'},
          <String, dynamic>{'SECTION': 'D31 (2mm)', 'DULL': '2'},
        ],
      });
      expect(bad.rows, hasLength(1));
      expect(bad.rows.single.section, 'D31 (2mm)');
    });
  });

  test('a row survives a round trip through json', () {
    const RateRow row = RateRow(
      section: 'DC26F (1.6mm)',
      byColour: <String, String>{'DULL': '912', 'H23/PC-RAL': '915'},
    );
    final RateRow back = RateRow.fromJson(row.toJson());
    expect(back.section, row.section);
    expect(back.byColour, row.byColour);
  });
}
