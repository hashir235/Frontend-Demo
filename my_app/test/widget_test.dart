import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app.dart';

const Key _pageViewKey = Key('window_page_view');
const Key _focusedCodeNameKey = Key('focused_code_name');

Future<void> _openAddWindows(WidgetTester tester) async {
  await tester.tap(find.text('Estimation'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add Windows'));
  await tester.pumpAndSettle();
}

Future<void> _tapFocusedCard(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(find.byKey(_pageViewKey)));
  await tester.pumpAndSettle();
}

Future<void> _enterInputValues(
  WidgetTester tester, {
  required String height,
  required String width,
  String? description,
}) async {
  await tester.enterText(find.byKey(const Key('input_height_field')), height);
  await tester.enterText(find.byKey(const Key('input_width_field')), width);
  if (description != null) {
    await tester.enterText(
      find.byKey(const Key('input_description_field')),
      description,
    );
  }
}

Future<void> _tapSaveButton(WidgetTester tester) async {
  final Finder saveButton = find.byKey(const Key('input_save_button'));
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Add Windows opens navigation screen with code name labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await _openAddWindows(tester);

    expect(
      find.byKey(const Key('navigation_estimation_heading')),
      findsOneWidget,
    );
    expect(find.byKey(_pageViewKey), findsOneWidget);
    expect(find.byKey(_focusedCodeNameKey), findsOneWidget);
  });

  testWidgets('Leaf card opens input page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await _openAddWindows(tester);

    await _tapFocusedCard(tester);

    expect(find.byKey(const Key('input_estimation_heading')), findsOneWidget);
    expect(find.byKey(const Key('input_window_label')), findsOneWidget);
    expect(find.text('Sliding Window'), findsOneWidget);
    expect(find.byKey(const Key('current_win_no_label')), findsOneWidget);
  });

  testWidgets('Save with optional description shows it in review list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await _openAddWindows(tester);
    await _tapFocusedCard(tester);

    await _enterInputValues(
      tester,
      height: '45.7',
      width: '22.4',
      description: 'bath room window',
    );
    await _tapSaveButton(tester);

    await tester.tap(find.byKey(const Key('open_review_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review_item_1')), findsOneWidget);
    expect(
      find.textContaining('Description: bath room window'),
      findsOneWidget,
    );
  });

  testWidgets('Save without description keeps review row clean', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await _openAddWindows(tester);
    await _tapFocusedCard(tester);

    await _enterInputValues(tester, height: '21.3', width: '11.2');
    await _tapSaveButton(tester);

    await tester.tap(find.byKey(const Key('open_review_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review_item_1')), findsOneWidget);
    expect(find.textContaining('Description:'), findsNothing);
  });

  testWidgets(
    'Edit description updates same winNo and delete keeps numbering monotonic',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await _openAddWindows(tester);
      await _tapFocusedCard(tester);

      await _enterInputValues(
        tester,
        height: '31.6',
        width: '12.3',
        description: 'bath room window',
      );
      await _tapSaveButton(tester);

      await _enterInputValues(tester, height: '32.6', width: '13.3');
      await _tapSaveButton(tester);

      await tester.tap(find.byKey(const Key('open_review_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_item_1')), findsOneWidget);
      expect(find.byKey(const Key('review_item_2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('review_edit_1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('input_description_field')),
        'updated bathroom window',
      );
      await _tapSaveButton(tester);

      expect(find.byKey(const Key('review_item_1')), findsOneWidget);
      expect(find.textContaining('updated bathroom window'), findsOneWidget);

      await tester.tap(find.byKey(const Key('review_delete_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_item_1')), findsNothing);
      expect(find.byKey(const Key('review_item_2')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('winNo: 3'), findsOneWidget);
    },
  );
}
