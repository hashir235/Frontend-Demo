import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/estimation/data/project_api_client.dart';
import 'package:my_app/features/estimation/data/project_repository.dart';
import 'package:my_app/features/estimation/models/window_material.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/presentation/review_list_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/state/last_glass_color.dart';
import 'package:my_app/features/estimation/state/last_window_material.dart';
import 'package:my_app/features/flow_nav/models/flow_step.dart';
import 'package:my_app/features/flow_nav/state/flow_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Review's Gauge, Aluminium and Glass: one tap puts it on every window that
/// comes in it, saves the job, and can be undone.
void main() {
  late List<List<dynamic>> saved;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlowProgress.instance.resetForTest();
    FlowProgress.instance.enter(estimationFlow);
    saved = <List<dynamic>>[];
  });

  ProjectRepository repository() => ProjectRepository(
    apiClient: ProjectApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((http.Request request) async {
        if (request.method == 'PUT' &&
            request.url.path == '/api/projects/p1/windows') {
          saved.add(
            (jsonDecode(request.body) as Map<String, dynamic>)['windows']
                as List<dynamic>,
          );
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'p1',
              'context': 'estimation',
              'projectName': 'House 12',
              'projectLocation': 'Lahore',
              'status': 'in_progress',
              'windowCount': 3,
              'windows': <dynamic>[],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    ),
  );

  EstimateSessionStore job() {
    final EstimateSessionStore store = EstimateSessionStore(
      projectId: 'p1',
      projectName: 'House 12',
      projectLocation: 'Lahore',
    );
    void add(int no, String code, String label, WindowMaterial material) {
      store.addItem(
        winNo: no,
        windowLabel: label,
        windowCode: code,
        windowIndex: 1,
        collarIndex: 1,
        unitMode: UnitMode.inches,
        heightValue: '48',
        widthValue: '60',
        material: material,
        glassColor: 'Clear Glass',
      );
    }

    add(
      1,
      'S_win',
      'Sliding Window',
      const WindowMaterial(gauge: '1.2mm', color: 'DULL'),
    );
    add(
      2,
      'S_win',
      'Sliding Window',
      const WindowMaterial(gauge: '2mm', color: 'DULL'),
    );
    add(
      3,
      'SPE_win',
      'Prime Economy',
      const WindowMaterial(gauge: '0.9mm', color: 'DULL'),
    );
    return store;
  }

  Future<void> open(WidgetTester tester, EstimateSessionStore store) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewListScreen(session: store, projectRepository: repository()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String button, String value) async {
    await tester.tap(find.byKey(Key(button)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('apply_choice_$value')));
    await tester.pumpAndSettle();
  }

  List<String> gauges(EstimateSessionStore store) =>
      store.items.map((WindowReviewItem i) => i.material.gauge).toList();

  testWidgets('the three buttons sit at the top of Review', (
    WidgetTester tester,
  ) async {
    await open(tester, job());
    expect(find.text('Change for every window'), findsOneWidget);
    expect(find.byKey(const Key('review_apply_gauge')), findsOneWidget);
    expect(find.byKey(const Key('review_apply_aluminium')), findsOneWidget);
    expect(find.byKey(const Key('review_apply_glass')), findsOneWidget);
  });

  testWidgets(
    'the gauge list: every gauge the job comes in, what each reaches',
    (WidgetTester tester) async {
      await open(tester, job());
      await tester.tap(find.byKey(const Key('review_apply_gauge')));
      await tester.pumpAndSettle();

      for (final String gauge in <String>['0.9mm', '1.2mm', '1.6mm', '2mm']) {
        expect(find.byKey(Key('apply_choice_$gauge')), findsOneWidget);
      }
      expect(find.text('For 2 of 3 windows · On 1 of 3 now'), findsNWidgets(2));
      expect(find.text('For 2 of 3 windows · On none now'), findsOneWidget);
      expect(find.text('For 1 of 3 windows · On 1 of 3 now'), findsOneWidget);
    },
  );

  testWidgets('a gauge goes on every window made in it; the rest keep theirs', (
    WidgetTester tester,
  ) async {
    final EstimateSessionStore store = job();
    await open(tester, store);
    // Each window's card names its gauge.
    expect(find.text('1.2mm · Dull'), findsOneWidget);
    expect(find.text('2mm · Dull'), findsOneWidget);
    expect(find.text('0.9mm · Dull Silver'), findsOneWidget);

    await choose(tester, 'review_apply_gauge', '2mm');

    expect(gauges(store), <String>['2mm', '2mm', '0.9mm']);
    // The cards show it straight away.
    expect(find.text('1.2mm · Dull'), findsNothing);
    expect(find.text('2mm · Dull'), findsNWidgets(2));
    expect(find.text('0.9mm · Dull Silver'), findsOneWidget);
    expect(
      find.text(
        '2mm on 1 window. 1 window does not come in 2mm and kept its own.',
      ),
      findsOneWidget,
    );
    expect(saved, hasLength(1), reason: 'saved to the project at once');
    expect(
      saved.single.map((dynamic w) => (w as Map<String, dynamic>)['gauge']),
      <String>['2mm', '2mm', '0.9mm'],
    );
    // The next new job opens on it too.
    expect(LastWindowMaterial.instance.value.gauge, '2mm');
  });

  testWidgets('Undo puts every window back and saves that', (
    WidgetTester tester,
  ) async {
    final EstimateSessionStore store = job();
    await open(tester, store);
    await choose(tester, 'review_apply_gauge', '1.6mm');
    expect(gauges(store), <String>['1.6mm', '1.6mm', '0.9mm']);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(gauges(store), <String>['1.2mm', '2mm', '0.9mm']);
    expect(saved, hasLength(2));
  });

  testWidgets('aluminium goes on every window, Prime Economy included', (
    WidgetTester tester,
  ) async {
    final EstimateSessionStore store = job();
    await open(tester, store);
    await choose(tester, 'review_apply_aluminium', AluminiumColors.black);

    expect(
      store.items.map((WindowReviewItem i) => i.material.color),
      everyElement(AluminiumColors.black),
    );
    expect(gauges(store), <String>[
      '1.2mm',
      '2mm',
      '0.9mm',
    ], reason: 'gauges untouched');
    expect(find.text('Black aluminium on 3 windows.'), findsOneWidget);
    expect(saved, hasLength(1));
  });

  testWidgets('glass goes on every window', (WidgetTester tester) async {
    final EstimateSessionStore store = job();
    await open(tester, store);
    await choose(tester, 'review_apply_glass', 'Gray Mercury');

    expect(
      store.items.map((WindowReviewItem i) => i.glassColor),
      everyElement('Gray Mercury'),
    );
    expect(
      store.items.map((WindowReviewItem i) => i.material),
      <WindowMaterial>[
        const WindowMaterial(gauge: '1.2mm', color: 'DULL'),
        const WindowMaterial(gauge: '2mm', color: 'DULL'),
        const WindowMaterial(gauge: '0.9mm', color: 'DULL'),
      ],
    );
    expect(find.text('Gray Mercury glass on 3 windows.'), findsOneWidget);
    expect(LastGlassColor.instance.value, 'Gray Mercury');
    expect(saved, hasLength(1));
  });

  testWidgets('already on every window: says so, saves nothing', (
    WidgetTester tester,
  ) async {
    await open(tester, job());
    await choose(tester, 'review_apply_aluminium', AluminiumColors.dull);

    expect(find.text('Every window is already in Dull.'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(saved, isEmpty);
  });

  testWidgets('closing the list changes nothing', (WidgetTester tester) async {
    final EstimateSessionStore store = job();
    await open(tester, store);
    await tester.tap(find.byKey(const Key('review_apply_gauge')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(gauges(store), <String>['1.2mm', '2mm', '0.9mm']);
    expect(saved, isEmpty);
  });
}
