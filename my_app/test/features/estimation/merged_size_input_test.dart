import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/size_entry_notation.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/settings/state/app_settings.dart';
import 'package:my_app/features/settings/state/size_input_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One box for a whole size, the way a fitter says it.
///
/// "Twenty-three four" is one number to a person and two to the app. Typing it
/// into two boxes costs a tap between them for every dimension of every window
/// in a project, so it goes into one box with a space -- and the space has to
/// come back out as exactly the size the two boxes would have produced,
/// because what is stored here is what gets cut.
void main() {
  group('inch and suter, in one box', () {
    for (final (String typed, String stored, String reads) in <
        (String, String, String)>[
      ('23 4', '23.4', '23 inch 4 suter'),
      ('44 5.5', '44.55', '44 inch, five and a half suter'),
      ('32 0.5', '32.05', '32 inch, half a suter'),
      ('23', '23.0', '23 inch, nothing over'),
      ('  23   4  ', '23.4', 'spaces around and between'),
    ]) {
      test('"$typed" is $reads', () {
        expect(SizeNotation.mergedToStored(typed, isFeet: false), stored);
      });
    }

    test('what is stored comes back the way it was typed', () {
      // A saved window opened for editing has to show the size its owner
      // entered, not the notation the app keeps it in. It comes back wearing
      // the tape marks, so it is compared with them stripped off.
      for (final String typed in <String>['23 4', '44 5.5', '32 0.5', '23']) {
        final String stored = SizeNotation.mergedToStored(typed, isFeet: false);
        final String shown = SizeNotation.storedToMerged(stored, isFeet: false);
        expect(SizeNotation.stripMarks(shown), typed);
      }
    });

    test('the merged box and the two boxes agree', () {
      // The same size, entered both ways, has to store identically -- the
      // setting is meant to change the typing, not the window.
      expect(
        SizeNotation.mergedToStored('44 5.5', isFeet: false),
        SizeNotation.combineInchSuter('44', '5.5'),
      );
      expect(
        SizeNotation.mergedToStored('23', isFeet: false),
        SizeNotation.combineInchSuter('23', ''),
      );
    });
  });

  group('the tape marks', () {
    // A bare "34 4" says nothing about which number is which. The marks are
    // the notation already read off a tape, and they appear as the size is
    // typed so the box tells the fitter where he has got to.
    for (final (String bare, String shown, String why) in <
        (String, String, String)>[
      ('3', "3''", 'marked from the very first digit, not after the space'),
      ('34', "34''", 'still the inch'),
      ('34 ', "34'' ", 'space pressed, nothing typed after it yet'),
      ('34 4', "34'' 4'''", 'the suter in'),
      ('34 4.5', "34'' 4.5'''", 'half a suter'),
      ('34 4.', "34'' 4.", 'mid-typing: no marks over an unfinished decimal'),
      ('', '', 'an empty box stays empty'),
    ]) {
      test('"$bare" shows as "$shown" -- $why', () {
        expect(SizeNotation.displayMerged(bare), shown);
      });
    }

    // One quote is feet, two inches, three suter -- so which mark a part wears
    // depends on the unit the screen is in, not on where it sits.
    for (final (String bare, String shown, String why) in <
        (String, String, String)>[
      ('13', "13'", 'feet, from the first digit'),
      ('13 ', "13' ", 'space pressed'),
      ('13 7', "13' 7''", 'feet and inch'),
    ]) {
      test('in feet, "$bare" shows as "$shown" -- $why', () {
        expect(SizeNotation.displayMerged(bare, isFeet: true), shown);
      });
    }

    test('the marks are decoration, never part of the size', () {
      // Everything that reads a box comes through the same reader, so a quote
      // can never be mistaken for a digit.
      // 4.5 suter is stored as the two digits 45 -- the half goes in as a
      // second digit, not a second dot, so the whole size survives as one
      // number.
      expect(SizeNotation.mergedToStored("34'' 4.5'''", isFeet: false), '34.45');
      expect(SizeNotation.mergedToStored("43'' 3'''", isFeet: false), '43.3');
      expect(SizeNotation.mergedToStored("23''", isFeet: false), '23.0');
      expect(
        SizeNotation.mergedToStored("34'' 4.5'''", isFeet: false),
        SizeNotation.mergedToStored('34 4.5', isFeet: false),
        reason: 'marked and bare must store identically',
      );
    });

    test('a stored size opens wearing its marks', () {
      expect(SizeNotation.storedToMerged('34.45', isFeet: false), "34'' 4.5'''");
      expect(SizeNotation.storedToMerged('23.0', isFeet: false), "23''");
      // Feet wear one quote, and the inch after them two.
      expect(SizeNotation.storedToMerged('13.7', isFeet: true), "13' 7''");
      expect(SizeNotation.storedToMerged('4.0', isFeet: true), "4'");
    });

    test('rubbish is dropped rather than stored', () {
      expect(SizeNotation.stripMarks("ab34''cd 4"), '34 4');
      // A second space would read as a third part, which is a typo, not a size.
      expect(SizeNotation.stripMarks('34   4'), '34 4');
    });
  });

  group('typing into the box', () {
    const MergedSizeFormatter formatter = MergedSizeFormatter();

    TextEditingValue type(TextEditingValue from, String added) {
      // An empty value carries no selection at all (offset -1), which is
      // where a box starts before anything is typed into it.
      final int at =
          from.selection.end < 0 ? from.text.length : from.selection.end;
      final String next =
          from.text.substring(0, at) + added + from.text.substring(at);
      return formatter.formatEditUpdate(
        from,
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: at + added.length),
        ),
      );
    }

    test('the marks appear as the size goes in', () {
      TextEditingValue v = TextEditingValue.empty;
      v = type(v, '3');
      expect(
        v.text,
        "3''",
        reason: 'marked on the first digit -- a bare number says nothing',
      );
      v = type(v, '4');
      expect(v.text, "34''", reason: 'still on the inch');
      v = type(v, ' ');
      expect(v.text, "34'' ", reason: 'space settles the inch');
      v = type(v, '4');
      expect(v.text, "34'' 4'''");
      v = type(v, '.');
      v = type(v, '5');
      expect(v.text, "34'' 4.5'''");
      expect(SizeNotation.mergedToStored(v.text, isFeet: false), '34.45');
    });

    test('the caret stays with the digits, not at the end', () {
      // A masked field that throws the caret past the quotes on every
      // keystroke is worse than no mask: the next digit lands outside the size.
      TextEditingValue v = TextEditingValue.empty;
      for (final String ch in <String>['3', '4', ' ', '4']) {
        v = type(v, ch);
      }
      expect(v.text, "34'' 4'''");
      expect(
        v.selection.end,
        v.text.indexOf("'''"),
        reason: 'sitting after the 4, before its marks',
      );
    });

    test('a size can still be corrected in the middle', () {
      TextEditingValue v = TextEditingValue.empty;
      for (final String ch in <String>['3', '4', ' ', '4']) {
        v = type(v, ch);
      }
      // Put the caret after the first digit and backspace it.
      v = formatter.formatEditUpdate(
        v,
        const TextEditingValue(
          text: "4'' 4'''",
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
      expect(SizeNotation.stripMarks(v.text), '4 4');
    });

    test('letters never reach the box', () {
      final TextEditingValue v = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'ab12cd',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(v.text, "12''");
    });

    test('a feet box marks feet, then inches', () {
      const MergedSizeFormatter feet = MergedSizeFormatter(isFeet: true);
      TextEditingValue v = feet.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '13',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(v.text, "13'");
      v = feet.formatEditUpdate(
        v,
        TextEditingValue(
          text: '${v.text} 7',
          selection: TextSelection.collapsed(offset: v.text.length + 2),
        ),
      );
      expect(v.text, "13' 7''");
      expect(SizeNotation.mergedToStored(v.text, isFeet: true), '13.7');
    });
  });

  group('feet and inch, in one box', () {
    test('"4 9" is four feet nine', () {
      expect(SizeNotation.mergedToStored('4 9', isFeet: true), '4.9');
    });

    test('"4" is four feet', () {
      expect(SizeNotation.mergedToStored('4', isFeet: true), '4.0');
    });

    test('nothing typed stores nothing', () {
      expect(SizeNotation.mergedToStored('   ', isFeet: true), '');
      expect(SizeNotation.mergedToStored('   ', isFeet: false), '');
    });
  });

  group('what is refused', () {
    test('a third number is a typo, not a size', () {
      expect(SizeNotation.validateMergedInches('23 4 5'), isNotNull);
    });

    test('eight suter would be the next inch', () {
      expect(SizeNotation.validateMergedInches('23 8'), isNotNull);
      expect(SizeNotation.validateMergedInches('23 7.5'), isNull);
    });

    test('an empty box is required, not zero', () {
      expect(SizeNotation.validateMergedInches(''), 'Required');
    });

    test('a window measuring nothing is refused', () {
      expect(SizeNotation.validateMergedInches('0 4'), isNotNull);
    });

    test('a fraction of an inch belongs on the suter', () {
      expect(SizeNotation.validateMergedInches('23.5 4'), isNotNull);
    });

    test('the sizes the user asked for all pass', () {
      for (final String typed in <String>['23 4', '44 5.5', '32 0.5']) {
        expect(SizeNotation.validateMergedInches(typed), isNull, reason: typed);
      }
    });
  });

  group('on screen', () {
    const WindowType node = WindowType(
      label: 'Sliding Window',
      graphicKey: 'sliding_basic',
      children: <WindowType>[],
      displayIndex: 1,
      codeName: 'S_win',
    );

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      AppSettings.instance.setSizeInputMode(SizeInputMode.mergedKeypad);
    });

    Finder fieldByLabel(String label) => find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.labelText == label,
    );

    testWidgets('width is the first box and height sits beside it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindowInputScreen(
            node: node,
            session: EstimateSessionStore(
              projectName: 'Test Project',
              projectLocation: 'Test Location',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder width = fieldByLabel('Width');
      final Finder height = fieldByLabel('Height');
      expect(width, findsOneWidget);
      expect(height, findsOneWidget);

      final Offset widthAt = tester.getTopLeft(width);
      final Offset heightAt = tester.getTopLeft(height);
      expect(
        widthAt.dx,
        lessThan(heightAt.dx),
        reason: 'width is the left-hand box',
      );
      expect(
        widthAt.dy,
        closeTo(heightAt.dy, 1),
        reason: 'and they share a line rather than stacking',
      );
    });

    testWidgets('a merged size typed on the screen is accepted', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindowInputScreen(
            node: node,
            session: EstimateSessionStore(
              projectName: 'Test Project',
              projectLocation: 'Test Location',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The space has to survive the field's own input filter, which is the
      // one place a merged size could be silently truncated to "234". It comes
      // back wearing the tape marks, which is what the box is meant to show.
      await tester.enterText(fieldByLabel('Width'), '44 5.5');
      await tester.pumpAndSettle();

      expect(find.text("44'' 5.5'''"), findsOneWidget);
    });
  });
}
