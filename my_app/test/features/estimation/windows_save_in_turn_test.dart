import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/estimation/data/project_api_client.dart';
import 'package:my_app/features/estimation/data/project_repository.dart';
import 'package:my_app/features/estimation/models/saved_project.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';

/// A server that answers each save only when told to, and remembers the
/// order the lists arrived in.
class _SlowServer extends ProjectApiClient {
  _SlowServer() : super(httpClient: MockClient((_) async => http.Response('{}', 500)));

  final List<List<WindowReviewItem>> sent = <List<WindowReviewItem>>[];
  final List<Completer<void>> answers = <Completer<void>>[];
  List<WindowReviewItem>? kept;

  @override
  Future<SavedProjectDetail> saveProjectWindows({
    required String projectId,
    required List<WindowReviewItem> windows,
  }) async {
    sent.add(windows);
    final Completer<void> answer = Completer<void>();
    answers.add(answer);
    await answer.future;
    kept = windows;
    return SavedProjectDetail.fromJson(<String, dynamic>{'id': projectId, 'windows': <dynamic>[]});
  }
}

void main() {
  late _SlowServer server;
  late ProjectRepository repository;
  late EstimateSessionStore session;

  setUp(() {
    server = _SlowServer();
    repository = ProjectRepository(apiClient: server);
    session = EstimateSessionStore(projectId: 'p1', projectName: 'P', projectLocation: 'L');
    session.addItem(
      winNo: 1,
      windowLabel: 'Sliding Window',
      windowCode: 'S_win',
      windowIndex: 1,
      collarIndex: 1,
      unitMode: UnitMode.inches,
      heightValue: '30.0',
      widthValue: '40.0',
    );
  });

  test('an edit saved while an older save is on its way is the one kept', () async {
    // A save of the window as it was, still on its way...
    final Future<void> first = repository.syncSession(session);
    await pumpEventQueue();
    expect(server.sent, hasLength(1));

    // ...when the window is edited and saved again.
    session.updateItem(session.items.single.copyWith(heightValue: '36.0'));
    final Future<void> second = repository.syncSession(session);
    await pumpEventQueue();
    expect(server.sent, hasLength(1), reason: 'the edit waits for the save before it');

    server.answers[0].complete();
    await first;
    await pumpEventQueue();
    expect(server.sent, hasLength(2));
    expect(server.sent[1].single.heightValue, '36.0', reason: 'read when its turn came');

    server.answers[1].complete();
    await second;
    expect(server.kept!.single.heightValue, '36.0');
  });

  test('saves asked for while one waits are that one', () async {
    final Future<void> first = repository.syncSession(session);
    await pumpEventQueue();
    final List<Future<void>> more = <Future<void>>[
      for (int i = 0; i < 3; i++) repository.syncSession(session),
    ];
    await pumpEventQueue();
    server.answers[0].complete();
    await first;
    await pumpEventQueue();
    expect(server.sent, hasLength(2), reason: 'one more save, not three');
    server.answers[1].complete();
    await Future.wait(more);
    expect(server.sent, hasLength(2));
  });

  test('a save that fails does not stop the next one', () async {
    final Future<void> first = repository.syncSession(session);
    await pumpEventQueue();
    session.updateItem(session.items.single.copyWith(heightValue: '36.0'));
    final Future<void> second = repository.syncSession(session);
    await pumpEventQueue();

    server.answers[0].completeError(const ProjectApiException('Project save failed.'));
    await expectLater(first, throwsA(isA<ProjectApiException>()));
    await pumpEventQueue();
    expect(server.sent, hasLength(2));
    server.answers[1].complete();
    await second;
    expect(server.kept!.single.heightValue, '36.0');
  });
}
