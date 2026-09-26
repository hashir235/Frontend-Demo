import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/estimation/data/project_api_client.dart';
import 'package:my_app/features/estimation/data/project_repository.dart';
import 'package:my_app/features/estimation/models/saved_project.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/presentation/estimation_menu_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A server whose project creation answers only when the test says so.
class _SlowServer extends ProjectApiClient {
  _SlowServer()
    : super(
        httpClient: MockClient((http.Request _) async => http.Response('{}', 500)),
        baseUrl: 'http://test.invalid',
      );

  final Completer<String> project = Completer<String>();
  int createCalls = 0;
  final List<String> savedInto = <String>[];

  SavedProjectDetail _detail(String id) => SavedProjectDetail(
    id: id,
    context: 'estimation',
    projectName: 'Test',
    projectLocation: 'Lahore',
    status: 'draft',
    windowCount: 0,
    updatedAt: null,
    windows: const <WindowReviewItem>[],
    outputs: null,
  );

  @override
  Future<SavedProjectDetail> createProject({
    required String context,
    required String projectName,
    required String projectLocation,
  }) async {
    createCalls++;
    return _detail(await project.future);
  }

  @override
  Future<SavedProjectDetail> saveProjectWindows({
    required String projectId,
    required List<WindowReviewItem> windows,
  }) async {
    savedInto.add(projectId);
    return _detail(projectId);
  }
}

/// Pressing Create opens the window library at once; the project is written
/// to the server behind it. These hold the parts that make that safe.
void main() {
  EstimateSessionStore newSession() =>
      EstimateSessionStore(projectName: 'Test', projectLocation: 'Lahore');

  group('a new project, written behind the library', () {
    test('the session is usable before its project exists, and learns its id',
        () async {
      final EstimateSessionStore session = newSession();
      final Completer<String?> server = Completer<String?>();
      session.startCreatingProject(() => server.future);

      expect(session.projectId, isNull, reason: 'nothing waited for the server');
      expect(session.savesToProject, isTrue);

      final Future<String?> ready = session.ensureProject();
      server.complete('p-1');
      expect(await ready, 'p-1');
      expect(session.projectId, 'p-1');
    });

    test('a failed attempt is tried again -- once, however many are waiting',
        () async {
      int calls = 0;
      final EstimateSessionStore session = newSession();
      session.startCreatingProject(() async {
        calls++;
        if (calls == 1) throw Exception('no signal');
        return 'p-2';
      });

      // Two saves landing together must not make two projects.
      final List<String?> ids = await Future.wait(<Future<String?>>[
        session.ensureProject(),
        session.ensureProject(),
      ]);
      expect(ids, <String?>['p-2', 'p-2']);
      expect(calls, 2);
    });

    test('when it still cannot be made, the answer is null, not an error',
        () async {
      final EstimateSessionStore session = newSession();
      session.startCreatingProject(() async => throw Exception('offline'));
      expect(await session.ensureProject(), isNull);
      expect(session.projectId, isNull);
    });

    test('a session with no project needs none', () async {
      final EstimateSessionStore session = newSession();
      expect(session.savesToProject, isFalse);
      expect(await session.ensureProject(), isNull);

      final EstimateSessionStore reopened = EstimateSessionStore(
        projectId: 'p-old',
        projectName: 'Old',
        projectLocation: 'Lahore',
      );
      expect(reopened.savesToProject, isTrue);
      expect(await reopened.ensureProject(), 'p-old');
    });

    test('a window saved before the project exists is saved into it once it does',
        () async {
      final _SlowServer server = _SlowServer();
      final ProjectRepository repository = ProjectRepository(apiClient: server);
      final EstimateSessionStore session = newSession();
      session.startCreatingProject(() async {
        final SavedProjectDetail project = await repository.createProject(
          flow: EstimateFlow.estimation,
          projectName: 'Test',
          projectLocation: 'Lahore',
        );
        return project.id;
      });

      final Future<void> saving = repository.syncSession(session);
      await Future<void>.delayed(Duration.zero);
      expect(server.savedInto, isEmpty, reason: 'it waits for the project');

      server.project.complete('p-3');
      await saving;
      expect(server.savedInto, <String>['p-3']);
    });
  });

  group('on screen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('Create opens the window library without waiting for the server',
        (WidgetTester tester) async {
      final _SlowServer server = _SlowServer();
      await tester.pumpWidget(
        MaterialApp(
          home: EstimationMenuScreen(
            projectRepository: ProjectRepository(apiClient: server),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder create = find.text('Create Project');
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Project Name *'),
        'Test site',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Location *'),
        'Lahore',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The server has not answered, and the library is already open.
      expect(server.project.isCompleted, isFalse);
      expect(server.createCalls, 1, reason: 'the project is on its way');
      expect(
        find.byKey(const Key('navigation_estimation_heading')),
        findsOneWidget,
      );

      server.project.complete('p-4');
      // Let the housekeeping call's own timeout run out.
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
