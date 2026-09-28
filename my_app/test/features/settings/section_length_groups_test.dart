import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/settings/presentation/section_length_groups.dart';

/// Bar lengths in settings, as two groups: Even (14, 16, 18) and Odd (15, 17,
/// 19, the collar sections). Every section sits in one; a tap moves it.
void main() {
  test('collar sections are the odd ones', () {
    for (final String collar in <String>['DC30F', 'DC26F', 'D54F', 'D51F', 'M30F', 'M26F', 'EC30F', 'EC26F', 'ET30', 'ET26']) {
      expect(SectionLengthGroups.isCollarSection(collar), isTrue, reason: collar);
    }
    for (final String plain in <String>['DC30C', 'DC26C', 'D29', 'M23', 'ET30A', 'ET26A', 'EC30B', 'D61A', 'PATTI4']) {
      expect(SectionLengthGroups.isCollarSection(plain), isFalse, reason: plain);
    }
  });

  test('which group lengths put a section in', () {
    expect(SectionLengthGroups.groupFor(<int>[14, 16, 18]), SectionLengthGroup.even);
    expect(SectionLengthGroups.groupFor(<int>[18, 14, 16]), SectionLengthGroup.even);
    expect(SectionLengthGroups.groupFor(<int>[15, 17, 19]), SectionLengthGroup.odd);
    expect(SectionLengthGroups.groupFor(<int>[12, 20]), SectionLengthGroup.other);
    expect(SectionLengthGroups.groupFor(<int>[14, 16]), SectionLengthGroup.other);
    expect(SectionLengthGroups.groupFor(null), SectionLengthGroup.other);
  });

  group('the screen', () {
    late Map<String, TextEditingController> controllers;

    Future<void> open(WidgetTester tester) async {
      controllers = <String, TextEditingController>{
        'DC30F': TextEditingController(text: '15, 17, 19'),
        'DC30C': TextEditingController(text: '14, 16, 18'),
        'D29': TextEditingController(text: '14, 16, 18'),
        'ET30': TextEditingController(text: '14, 16, 18'),
        'M23': TextEditingController(text: '12, 20'),
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) =>
                    SectionLengthGroups(
                      controllers: controllers,
                      onChanged: () => setState(() {}),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder inGroup(String group, String section) => find.descendant(
      of: find.byKey(Key('length_group_$group')),
      matching: find.byKey(Key('length_chip_$section')),
    );

    testWidgets('every section in its group; one with its own lengths apart', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(inGroup('odd', 'DC30F'), findsOneWidget);
      expect(inGroup('even', 'DC30C'), findsOneWidget);
      expect(inGroup('even', 'D29'), findsOneWidget);
      expect(inGroup('even', 'ET30'), findsOneWidget);
      expect(inGroup('other', 'M23'), findsOneWidget);
      expect(find.text('14 · 16 · 18 ft'), findsOneWidget);
      expect(find.text('15 · 17 · 19 ft'), findsOneWidget);
    });

    testWidgets('× moves a section to the other group', (WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.descendant(
        of: inGroup('even', 'D29'),
        matching: find.byIcon(Icons.close_rounded),
      ));
      await tester.pumpAndSettle();
      expect(inGroup('odd', 'D29'), findsOneWidget);
      expect(controllers['D29']!.text, '15, 17, 19', reason: 'what is saved');
    });

    testWidgets('Add brings a section in from the other group', (WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('length_add_even')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('length_pick_DC30F')), findsOneWidget);
      expect(find.byKey(const Key('length_pick_D29')), findsNothing, reason: 'already here');
      await tester.tap(find.byKey(const Key('length_pick_DC30F')));
      await tester.pumpAndSettle();
      expect(inGroup('even', 'DC30F'), findsOneWidget);
      expect(controllers['DC30F']!.text, '14, 16, 18');
    });

    testWidgets('lengths of its own stay until moved', (WidgetTester tester) async {
      await open(tester);
      expect(controllers['M23']!.text, '12, 20');
      await tester.tap(find.byKey(const Key('length_chip_M23')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odd: 15 · 17 · 19 ft'));
      await tester.pumpAndSettle();
      expect(inGroup('odd', 'M23'), findsOneWidget);
      expect(find.byKey(const Key('length_group_other')), findsNothing,
          reason: 'nothing left apart');
    });

    testWidgets('restore puts collar sections in Odd and the rest in Even', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Restore standard groups'));
      await tester.pumpAndSettle();
      expect(controllers['DC30F']!.text, '15, 17, 19');
      expect(controllers['ET30']!.text, '15, 17, 19', reason: 'ET30 is a collar section');
      expect(controllers['DC30C']!.text, '14, 16, 18');
      expect(controllers['M23']!.text, '14, 16, 18');
    });
  });
}
