import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/optimization_error_text.dart';

/// A user set a stock length of 238 (reading the field as inches). Every
/// section then failed, and the only thing shown was the engine's own wording,
/// which points nowhere near the setting that caused it.
void main() {
  test('the infeasible-plan error names the section and the real fix', () {
    const String raw =
        'No feasible stock plan for section D29 under the hard wastage cap '
        '(2ft). Add/change allowed lengths or use recalculation.';

    final String out = OptimizationErrorText.friendly(raw);

    expect(out, contains('D29'));
    expect(out.toLowerCase(), contains('feet'));
    expect(out.toLowerCase(), contains('recalculation'));
    expect(out, isNot(contains('hard wastage cap')));
  });

  test('falls back to the section-less wording when no section is named', () {
    const String raw = 'No feasible stock plan under the hard wastage cap.';
    expect(OptimizationErrorText.friendly(raw), contains('a section'));
  });

  test('the sutter error explains the format', () {
    const String raw =
        'winNo 1: inches mode requires a single sutter digit 0..7';
    final String out = OptimizationErrorText.friendly(raw);
    expect(out, contains('45.4'));
    expect(out.toLowerCase(), contains('sutter'));
  });

  test('a message we do not recognise is passed through untouched', () {
    const String raw = 'Some brand new failure nobody has mapped yet';
    expect(OptimizationErrorText.friendly(raw), raw);
  });

  test('a whole list is translated', () {
    final List<String> out = OptimizationErrorText.friendlyAll(<String>[
      'No feasible stock plan for section DC30F under the hard wastage cap (2ft).',
      'height must be positive',
    ]);
    expect(out, hasLength(2));
    expect(out.first, contains('DC30F'));
    expect(out.last.toLowerCase(), contains('height or width'));
  });
}
