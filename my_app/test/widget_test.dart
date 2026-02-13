import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/app.dart';

const Key _contextLabelKey = Key('navigation_context_label');
const Key _pageViewKey = Key('window_page_view');

Future<void> _openAddWindows(WidgetTester tester) async {
  await tester.tap(find.text('Estimation'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add Windows'));
  await tester.pumpAndSettle();
}

Future<void> _swipeLeft(WidgetTester tester, {int times = 1}) async {
  final Finder pageView = find.byKey(_pageViewKey);
  for (int i = 0; i < times; i++) {
    await tester.drag(pageView, const Offset(-450, 0));
    await tester.pumpAndSettle();
  }
}

String _currentContextLabel(WidgetTester tester) {
  final Text contextWidget = tester.widget<Text>(find.byKey(_contextLabelKey));
  return contextWidget.data ?? '';
}

Future<void> _focusOnCardByLabel(
  WidgetTester tester,
  String label, {
  int maxSwipes = 12,
}) async {
  for (int i = 0; i < maxSwipes; i++) {
    if (_currentContextLabel(tester).endsWith('/ $label')) {
      return;
    }
    await _swipeLeft(tester);
  }
  throw TestFailure('Could not focus card with label: $label');
}

Future<void> _tapFocusedCard(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(find.byKey(_pageViewKey)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Add Windows opens navigation screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await _openAddWindows(tester);

    expect(
      find.byKey(const Key('navigation_estimation_heading')),
      findsOneWidget,
    );
    expect(find.byKey(_pageViewKey), findsOneWidget);
    expect(find.text('Sliding Window'), findsWidgets);
  });

  testWidgets('Panel Windows has 4 children including Sliding Equal Panel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await _openAddWindows(tester);
    await _focusOnCardByLabel(tester, 'Panel Windows');

    expect(_currentContextLabel(tester), contains('/ Panel Windows'));
    await _tapFocusedCard(tester);

    expect(find.textContaining('Panel Windows / Center Fix'), findsOneWidget);

    await _focusOnCardByLabel(tester, 'Sliding Equal Panel', maxSwipes: 6);
    expect(find.text('Sliding Equal Panel'), findsOneWidget);
    expect(find.text('#6').evaluate().isNotEmpty, isTrue);

    await _tapFocusedCard(tester);

    expect(find.text('Selected'), findsOneWidget);
  });

  testWidgets(
    'Panel Windows M_Section has 4 children including Sliding Equal Panel',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      await _openAddWindows(tester);
      await _focusOnCardByLabel(tester, 'Panel Windows M_Section');

      expect(
        _currentContextLabel(tester),
        contains('/ Panel Windows M_Section'),
      );
      await _tapFocusedCard(tester);

      expect(
        find.textContaining('Panel Windows M_Section / Center Fix'),
        findsOneWidget,
      );

      await _focusOnCardByLabel(tester, 'Sliding Equal Panel', maxSwipes: 6);
      expect(find.text('Sliding Equal Panel'), findsOneWidget);
      expect(find.text('#10').evaluate().isNotEmpty, isTrue);
    },
  );

  testWidgets('Reindexed downstream values are visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await _openAddWindows(tester);

    await _focusOnCardByLabel(tester, 'Fix Window', maxSwipes: 12);
    expect(find.text('Fix Window'), findsOneWidget);
    expect(find.text('#19').evaluate().isNotEmpty, isTrue);

    await _focusOnCardByLabel(tester, 'Door', maxSwipes: 8);
    expect(_currentContextLabel(tester), contains('/ Door'));
    await _tapFocusedCard(tester);

    expect(find.text('Single Door'), findsOneWidget);
    expect(find.text('#22').evaluate().isNotEmpty, isTrue);
  });
}
