import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/estimation/data/project_api_client.dart';
import 'package:my_app/features/estimation/data/project_repository.dart';
import 'package:my_app/features/estimation/presentation/recent_projects_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';

/// Every project in the lists has a delete button. It asks first, then takes
/// the project off the list; if the server says no, the project stays.
void main() {
  late List<Map<String, dynamic>> stored;
  late List<String> deleteCalls;
  late http.Response Function(String id) answerDelete;

  Map<String, dynamic> project(int n) => <String, dynamic>{
    'id': 'p$n',
    'context': 'estimation',
    'projectName': 'Job $n',
    'projectLocation': 'Lahore',
    'status': 'draft',
    'windowCount': n,
    'updatedAt': DateTime.utc(2026, 9, 20 - n).toIso8601String(),
  };

  ProjectRepository repository() => ProjectRepository(
    apiClient: ProjectApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((http.Request request) async {
        if (request.method == 'DELETE') {
          final String id = request.url.pathSegments.last;
          deleteCalls.add(request.url.path);
          final http.Response answer = answerDelete(id);
          if (answer.statusCode == 200) {
            stored.removeWhere((Map<String, dynamic> p) => p['id'] == id);
          }
          return answer;
        }
        return http.Response(
          jsonEncode(<String, dynamic>{'ok': true, 'projects': stored}),
          200,
        );
      }),
    ),
  );

  setUp(() {
    stored = <Map<String, dynamic>>[for (int n = 1; n <= 5; n++) project(n)];
    deleteCalls = <String>[];
    answerDelete = (String id) => http.Response(
      jsonEncode(<String, dynamic>{'ok': true, 'deleted': true, 'projectId': id}),
      200,
    );
  });

  Future<void> openSection(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecentProjectsListSection(
              flow: EstimateFlow.estimation,
              moduleTitle: 'Estimation',
              repository: repository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('each project shown has a delete button', (
    WidgetTester tester,
  ) async {
    await openSection(tester);
    for (int n = 1; n <= 4; n++) {
      expect(find.byKey(Key('delete_project_p$n')), findsOneWidget);
    }
    // Only four are listed on the menu.
    expect(find.text('Job 5'), findsNothing);
  });

  testWidgets('cancel keeps the project and sends nothing', (
    WidgetTester tester,
  ) async {
    await openSection(tester);
    await tester.tap(find.byKey(const Key('delete_project_p2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete_project_dialog')), findsOneWidget);
    expect(find.textContaining('"Job 2" (Lahore)'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(deleteCalls, isEmpty);
    expect(find.text('Job 2'), findsOneWidget);
  });

  testWidgets('delete takes it off the list, and the next one moves up', (
    WidgetTester tester,
  ) async {
    await openSection(tester);
    await tester.tap(find.byKey(const Key('delete_project_p2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_project')));
    await tester.pumpAndSettle();

    expect(deleteCalls, <String>['/api/projects/p2']);
    expect(find.text('Job 2'), findsNothing);
    expect(find.text('"Job 2" deleted.'), findsOneWidget);
    expect(find.text('Job 5'), findsOneWidget, reason: 'four are shown again');
    // The others were not touched.
    expect(find.text('Job 1'), findsOneWidget);
    expect(find.text('Job 3'), findsOneWidget);
  });

  testWidgets('if the server refuses, the project stays and says so', (
    WidgetTester tester,
  ) async {
    answerDelete = (String id) => http.Response(
      jsonEncode(<String, dynamic>{'ok': false, 'error': 'project delete failed'}),
      500,
    );
    await openSection(tester);
    await tester.tap(find.byKey(const Key('delete_project_p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_project')));
    await tester.pumpAndSettle();

    expect(find.text('Job 1'), findsOneWidget);
    expect(find.textContaining('Could not delete the project.'), findsOneWidget);
  });

  testWidgets('a server too old to delete is not mistaken for a delete', (
    WidgetTester tester,
  ) async {
    answerDelete = (String id) =>
        http.Response('<pre>Cannot DELETE /api/projects/$id</pre>', 404);
    await openSection(tester);
    await tester.tap(find.byKey(const Key('delete_project_p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_project')));
    await tester.pumpAndSettle();

    expect(find.text('Job 1'), findsOneWidget);
    expect(find.textContaining('Could not delete the project.'), findsOneWidget);
  });

  testWidgets('already gone on the server counts as deleted', (
    WidgetTester tester,
  ) async {
    answerDelete = (String id) => http.Response(
      jsonEncode(<String, dynamic>{'ok': false, 'error': 'project not found'}),
      404,
    );
    await openSection(tester);
    await tester.tap(find.byKey(const Key('delete_project_p3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_project')));
    await tester.pumpAndSettle();

    expect(find.text('Job 3'), findsNothing);
  });

  testWidgets('the full list deletes too, and the menu list follows it', (
    WidgetTester tester,
  ) async {
    await openSection(tester);
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.text('Job 5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_project_p5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_project')));
    await tester.pumpAndSettle();
    expect(deleteCalls, <String>['/api/projects/p5']);
    expect(find.text('Job 5'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Job 1'), findsOneWidget);
    expect(find.text('Job 5'), findsNothing);
  });
}
