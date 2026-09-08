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
      // entered, not the notation the app keeps it in.
      for (final String typed in <String>['23 4', '44 5.5', '32 0.5', '23']) {
        final String stored = SizeNotation.mergedToStored(typed, isFeet: false);
        expect(SizeNotation.storedToMerged(stored, isFeet: false), typed);
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
      // one place a merged size could be silently truncated to "234".
      await tester.enterText(fieldByLabel('Width'), '44 5.5');
      await tester.pumpAndSettle();

      expect(find.text('44 5.5'), findsOneWidget);
    });
  });
}
