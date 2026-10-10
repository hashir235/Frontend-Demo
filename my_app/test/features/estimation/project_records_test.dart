import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/estimation/data/project_api_client.dart';
import 'package:my_app/features/estimation/data/project_repository.dart';
import 'package:my_app/features/estimation/models/saved_project.dart';
import 'package:my_app/features/estimation/presentation/recent_projects_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';

/// "View all": every job as a record -- site, place, customer, Grand Total,
/// Remaining, windows, status -- with a note the shop writes and saves on it.
void main() {
  late List<Uri> asked;
  late List<Map<String, dynamic>> notesSent;
  late List<Map<String, dynamic>> stored;

  Map<String, dynamic> project(
    String id,
    String name, {
    String location = 'Lahore',
    String status = 'billed',
    int windows = 8,
    String notes = '',
    Map<String, dynamic>? bill,
  }) => <String, dynamic>{
    'id': id,
    'context': 'estimation',
    'projectName': name,
    'projectLocation': location,
    'status': status,
    'windowCount': windows,
    'updatedAt': DateTime.utc(2026, 10, 9, 9, 5).toIso8601String(),
    'notes': notes,
    'bill': bill,
  };

  setUp(() {
    asked = <Uri>[];
    notesSent = <Map<String, dynamic>>[];
    stored = <Map<String, dynamic>>[
      project(
        'p1',
        'House 12',
        notes: 'Advance taken in cash',
        bill: <String, dynamic>{
          'customerName': 'Ahmed',
          'customerPhone': '0311-1111111',
          'grandTotal': 167708,
          'advancePaid': 50000,
          'remainingDue': 117708,
          'totalWindows': 8,
          'totalArea': 103.41,
          'areaMethod': '',
        },
      ),
      project(
        'p2',
        'Shop DHA',
        location: 'Karachi',
        status: 'in_progress',
        windows: 3,
      ),
      project(
        'p3',
        'Clinic',
        location: 'Multan',
        windows: 2,
        bill: <String, dynamic>{
          'customerName': 'Dr Sana',
          'customerPhone': '',
          'grandTotal': 45250.5,
          'advancePaid': 45250.5,
          'remainingDue': 0,
          'totalWindows': 2,
          'totalArea': 20,
          'areaMethod': 'running',
        },
      ),
    ];
  });

  ProjectRepository repository() => ProjectRepository(
    apiClient: ProjectApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((http.Request request) async {
        asked.add(request.url);
        if (request.method == 'PUT' && request.url.path.endsWith('/notes')) {
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          notesSent.add(body);
          return http.Response(
            jsonEncode(<String, dynamic>{
              'ok': true,
              'projectId': request.url.pathSegments[2],
              'notes': (body['notes'] as String).trim(),
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, dynamic>{'ok': true, 'projects': stored}),
          200,
        );
      }),
    ),
  );

  Future<void> open(
    WidgetTester tester, {
    EstimateFlow flow = EstimateFlow.estimation,
  }) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: RecentProjectsScreen(
          flow: flow,
          moduleTitle: 'Estimation',
          repository: repository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('asks for every record, with its bill', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(asked.single.queryParameters['details'], '1');
    expect(asked.single.queryParameters['limit'], '500');
    expect(asked.single.queryParameters['context'], 'estimation');
    expect(tester.takeException(), isNull);
  });

  testWidgets('each record: site, place, customer, totals, status, note', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(find.text('House 12'), findsOneWidget);
    expect(find.text('Lahore'), findsOneWidget);
    expect(find.text('Ahmed  ·  0311-1111111'), findsOneWidget);
    expect(find.text('Rs 167,708'), findsWidgets);
    expect(find.text('Rs 117,708'), findsWidgets);
    expect(find.text('Billed'), findsWidgets);
    expect(find.text('Advance taken in cash'), findsOneWidget);
    expect(
      find.text('Updated 9 Oct 2026, ${_hourMinute(9, 5)}'),
      findsNWidgets(3),
    );

    // Not billed yet: says so, and leaves the money blank rather than 0.
    expect(find.text('Bill not made yet'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Add a note'), findsNWidgets(2));

    // Paid in full.
    expect(find.text('Dr Sana'), findsOneWidget);
    expect(find.text('Rs 45,250.5'), findsOneWidget);
    expect(find.text('Remaining · Paid'), findsOneWidget);
  });

  testWidgets('the counts across the list', (WidgetTester tester) async {
    await open(tester);
    Finder inTile(String key, String text) =>
        find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
    expect(inTile('records_total_projects', '3'), findsOneWidget);
    expect(inTile('records_total_billed', 'Rs 212,958.5'), findsOneWidget);
    expect(inTile('records_total_remaining', 'Rs 117,708'), findsOneWidget);
  });

  testWidgets('search narrows by customer, site or place', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('records_search')), 'ahmed');
    await tester.pumpAndSettle();
    expect(find.text('House 12'), findsOneWidget);
    expect(find.text('Shop DHA'), findsNothing);
    expect(find.text('Clinic'), findsNothing);

    await tester.enterText(find.byKey(const Key('records_search')), 'karachi');
    await tester.pumpAndSettle();
    expect(find.text('Shop DHA'), findsOneWidget);
    expect(find.text('House 12'), findsNothing);

    await tester.enterText(find.byKey(const Key('records_search')), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches "nobody"'), findsOneWidget);
  });

  testWidgets('a note is written on the card and saved', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('record_notes_p2')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('project_notes_field')),
      'Glass comes Friday  ',
    );
    await tester.tap(find.byKey(const Key('project_notes_save')));
    await tester.pumpAndSettle();

    expect(notesSent, <Map<String, dynamic>>[
      <String, dynamic>{'notes': 'Glass comes Friday  '},
    ]);
    expect(asked.last.path, '/api/projects/p2/notes');
    expect(find.text('Glass comes Friday'), findsOneWidget);
    expect(find.text('Note saved.'), findsOneWidget);
  });

  testWidgets('closing the note without saving sends nothing', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('record_notes_p1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('project_notes_field')), 'x');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(notesSent, isEmpty);
    expect(find.text('Advance taken in cash'), findsOneWidget);
  });

  testWidgets('a cutting job has no bill to show', (WidgetTester tester) async {
    stored = <Map<String, dynamic>>[
      <String, dynamic>{
        ...project('f1', 'Factory', windows: 12),
        'context': 'fabrication',
        'bill': null,
      },
    ];
    await open(tester, flow: EstimateFlow.fabrication);
    expect(find.text('Factory'), findsOneWidget);
    expect(find.text('Grand Total'), findsNothing);
    expect(find.text('Bill not made yet'), findsNothing);
    expect(
      find.text('Windows'),
      findsNWidgets(2),
      reason: 'the tile and the card',
    );
    expect(tester.takeException(), isNull);
  });

  test('an old server with no bill or notes still reads', () {
    final SavedProjectSummary old =
        SavedProjectSummary.fromJson(<String, dynamic>{
          'id': 'p9',
          'context': 'estimation',
          'projectName': 'Old',
          'projectLocation': 'Lahore',
          'status': 'draft',
          'windowCount': 1,
        });
    expect(old.notes, '');
    expect(old.bill, isNull);
  });
}

String _hourMinute(int hour, int minute) {
  final DateTime local = DateTime.utc(2026, 10, 9, hour, minute).toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}
