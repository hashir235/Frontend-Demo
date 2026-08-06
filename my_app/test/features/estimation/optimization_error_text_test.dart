import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/optimization_error_text.dart';

/// Every failure a user can hit has to arrive as something they can act on.
///
/// A user once set a stock length of 238 (reading the field as inches). Every
/// section then failed, and the only thing shown was the engine's own wording
/// -- "No feasible stock plan for section D29 under the hard wastage cap
/// (2ft)" -- which points nowhere near the setting that caused it, and reads as
/// though the app is broken.
///
/// These tests pin each real engine string to an explanation that names the
/// cause and the screen to fix it on.
void main() {
  /// The wording each case must carry, so a rewrite that drops the actionable
  /// half fails here rather than in someone's workshop.
  void expectMentions(EstimationIssue issue, List<String> needles) {
    final String all = issue.combined.toLowerCase();
    for (final String needle in needles) {
      expect(
        all,
        contains(needle.toLowerCase()),
        reason: 'missing "$needle" in:\n${issue.combined}',
      );
    }
  }

  group('lengths', () {
    test('an infeasible plan names both causes and where to fix them', () {
      final EstimationIssue issue = OptimizationErrorText.explain(
        'No feasible stock plan for section D29 under the hard wastage cap '
        '(2ft). Add/change allowed lengths or use recalculation.',
      );

      expect(issue.section, 'D29');
      expectMentions(issue, <String>[
        'D29',
        'longer than',
        'wasting more than',
        'unit',
        'recalculation',
        'feet',
      ]);
      // The engine's own phrasing must not survive into the user's view.
      expect(issue.combined, isNot(contains('hard wastage cap')));
    });

    test('it still reads sensibly when no section is named', () {
      final EstimationIssue issue = OptimizationErrorText.explain(
        'No feasible stock plan under the hard wastage cap.',
      );

      expect(issue.section, isNull);
      expect(issue.combined, contains('a section'));
    });

    test('no lengths configured says which section and where to set them', () {
      final EstimationIssue issue = OptimizationErrorText.explain(
        'No allowed stock lengths configured for section M23',
      );

      expect(issue.section, 'M23');
      expectMentions(issue, <String>['M23', 'assigned lengths', 'feet']);
    });

    test('an unreadable length setting warns about the inches mistake', () {
      final EstimationIssue issue = OptimizationErrorText.explain(
        'invalid section length entry for D29',
      );

      expectMentions(issue, <String>['assigned lengths', '238', 'inches']);
    });
  });

  group('rates', () {
    test('a missing rate names the section and both ways out', () {
      final EstimationIssue issue = OptimizationErrorText.explain(
        'Missing rate for section DC26F',
      );

      expect(issue.section, 'DC26F');
      expectMentions(issue, <String>[
        'DC26F',
        'settings > rates',
        'gauge',
        'colour',
      ]);
    });
  });

  group('units and sizes', () {
    test('an unset unit mode points at the unit selector', () {
      for (final String raw in <String>[
        'unitMode must be cm or inches',
        'unitMode must be inches or feet',
      ]) {
        expectMentions(OptimizationErrorText.explain(raw), <String>[
          'unit',
          'size fields',
        ]);
      }
    });

    test('a bad sutter explains the rule and offers the unit as a cause', () {
      for (final String raw in <String>[
        'suter must be in range 0 <= suter < 8',
        'winNo 1: inches mode requires a single sutter digit 0..7',
        'suter precision must be one decimal digit',
      ]) {
        expectMentions(OptimizationErrorText.explain(raw), <String>[
          'sutter',
          '0 to 7',
          '45.4',
          'unit',
        ]);
      }
    });

    test('an unreadable size shows both accepted shapes', () {
      final EstimationIssue issue = OptimizationErrorText.explain(
        'dimension format is invalid',
      );

      expectMentions(issue, <String>['45.4', '4.6', 'unit']);
    });

    test('a zero size says which screen to open', () {
      for (final String raw in <String>[
        'height must be positive',
        'dimension must be greater than zero',
        'inch must be greater than zero',
      ]) {
        expectMentions(OptimizationErrorText.explain(raw), <String>[
          'review list',
          'height',
          'width',
        ]);
      }
    });

    test('a bad arch value is named as the arch', () {
      expectMentions(
        OptimizationErrorText.explain('invalid archValue: abc'),
        <String>['arch', 'unit'],
      );
    });
  });

  group('sections and input', () {
    test('an unsupported window says to re-add it', () {
      final EstimationIssue issue = OptimizationErrorText.explain(
        'unsupported window code in this phase: XYZ',
      );

      expectMentions(issue, <String>['review list', 'window library']);
    });

    test('an empty project says to add a window', () {
      for (final String raw in <String>[
        'no windows found in estimation snapshot',
        'no valid pieces found',
      ]) {
        expectMentions(OptimizationErrorText.explain(raw), <String>[
          'add at least one window',
        ]);
      }
    });

    test('no sections back points at windows saved without sizes', () {
      expectMentions(
        OptimizationErrorText.explain('sections array missing in optimization result'),
        <String>['without sizes', 'review list'],
      );
    });
  });

  group('our own failures', () {
    test('an unreadable snapshot does not blame the user', () {
      final EstimationIssue issue = OptimizationErrorText.explain(
        'failed to read estimation snapshot',
      );

      expectMentions(issue, <String>['our side', 'refresh']);
    });

    test('a bare "<x> failed" still suggests where to look', () {
      for (final String raw in <String>[
        'optimization failed',
        'cost table failed',
        'rate review failed',
        'billing estimate failed',
      ]) {
        expectMentions(OptimizationErrorText.explain(raw), <String>[
          'refresh',
          'unit',
        ]);
      }
    });
  });

  test('an unrecognised message is passed through, never swallowed', () {
    const String odd = 'Some brand new failure nobody has mapped yet';
    final EstimationIssue issue = OptimizationErrorText.explain(odd);

    expect(issue.message, odd);
    expect(OptimizationErrorText.friendly(odd), contains(odd));
  });

  group('transport', () {
    test('no network is named as no network', () {
      final EstimationIssue issue = OptimizationErrorText.forTransport(
        const SocketException('failed host lookup'),
      );

      expectMentions(issue, <String>['connection', 'nothing you entered']);
    });

    test('401 and 403 read as signed out, not as broken data', () {
      for (final int code in <int>[401, 403]) {
        expectMentions(
          OptimizationErrorText.forTransport(Exception('x'), statusCode: code),
          <String>['signed out', 'projects are safe'],
        );
      }
    });

    test('402 points at billing', () {
      expectMentions(
        OptimizationErrorText.forTransport(Exception('x'), statusCode: 402),
        <String>['plan', 'billing'],
      );
    });

    test('a 5xx is owned rather than blamed on the user', () {
      expectMentions(
        OptimizationErrorText.forTransport(Exception('x'), statusCode: 500),
        <String>['on us', 'not on your data'],
      );
    });

    test('a timeout explains why it can happen', () {
      expectMentions(
        OptimizationErrorText.forTransport(Exception('x'), statusCode: 504),
        <String>['too long', 'large project'],
      );
    });
  });

  test('friendlyAll keeps one entry per raw error', () {
    final List<String> out = OptimizationErrorText.friendlyAll(<String>[
      'Missing rate for section D29',
      'No allowed stock lengths configured for section M23',
    ]);

    expect(out, hasLength(2));
    expect(out.first, contains('D29'));
    expect(out.last, contains('M23'));
  });
}
