import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/saved_project.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';

/// Glass is its own kind of job, not fabrication with glass in it.
///
/// It starts from typed glass rows rather than from windows, so it must never
/// reach the window pipeline: a glass project sent through the window flow
/// shows an empty catalogue and looks broken. These tests pin the separation at
/// the two points it can go wrong -- what a session thinks it is, and what a
/// saved project reopens as.
SavedProjectSummary _project(String context) {
  return SavedProjectSummary(
    id: 'p1',
    context: context,
    projectName: 'Test Job',
    projectLocation: 'Test Town',
    status: 'draft',
    windowCount: 0,
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('session', () {
    test('a glass session is not a fabrication session', () {
      final EstimateSessionStore session = EstimateSessionStore(
        projectName: 'G',
        projectLocation: 'L',
        flow: EstimateFlow.glass,
      );

      expect(session.isGlass, isTrue);
      // Everything gated on isFabrication -- the window pipeline, rubber and
      // lock controls, the aluminium cutting flow -- must stay off for glass.
      expect(session.isFabrication, isFalse);
    });

    test('an aluminium session is not a glass session', () {
      final EstimateSessionStore session = EstimateSessionStore(
        projectName: 'A',
        projectLocation: 'L',
        flow: EstimateFlow.fabrication,
      );

      expect(session.isFabrication, isTrue);
      expect(session.isGlass, isFalse);
    });

    test('estimation is neither', () {
      final EstimateSessionStore session = EstimateSessionStore(
        projectName: 'E',
        projectLocation: 'L',
      );

      expect(session.isFabrication, isFalse);
      expect(session.isGlass, isFalse);
    });
  });

  group('saved project', () {
    test('a glass project knows it is glass and says so', () {
      final SavedProjectSummary project = _project('glass');

      expect(project.isGlass, isTrue);
      expect(project.kindLabel, 'Glass');
    });

    test('a fabrication project reads as aluminium', () {
      final SavedProjectSummary project = _project('fabrication');

      expect(project.isGlass, isFalse);
      expect(project.kindLabel, 'Aluminium');
    });

    test('an unknown context is treated as aluminium, never as glass', () {
      // Older rows saved before glass existed carry 'fabrication', and a
      // future kind we do not know about must not be routed to the glass
      // sheet by accident.
      for (final String context in <String>['', 'estimation', 'something']) {
        expect(_project(context).isGlass, isFalse, reason: 'context "$context"');
      }
    });
  });

  test('the flow enum carries all three kinds', () {
    expect(EstimateFlow.values, hasLength(3));
    expect(EstimateFlow.values, contains(EstimateFlow.glass));
  });
}
