import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/model/formula_expression.dart';
import 'package:my_app/features/formulas/model/formula_slot.dart';

/// A formula is stored in the engine's names and read in the fabricator's.
/// These hold the translation between them: what is shown has to be the same
/// arithmetic as what is cut to, in both directions and after any number of
/// trips.
void main() {
  FormulaSlot slot(
    String section,
    String label,
    String stored, {
    bool fabrication = true,
  }) {
    return FormulaSlot(
      section: section,
      label: label,
      stored: stored,
      isFabrication: fabrication,
    );
  }

  group('showing a formula in the piece\'s own name', () {
    test('a height piece reads as its label', () {
      expect(slot('DC30C', 'HL', '(h + cm) / feet').display, '(HL + cm) / feet');
      expect(slot('DC30C', 'HR', '(h - 4.2 + cm) / feet').display, '(HR - 4.2 + cm) / feet');
    });

    test('a width piece reads as its label', () {
      expect(slot('DC30C', 'WT', '(w + cm) / feet').display, '(WT + cm) / feet');
      expect(
        slot('M24', 'W1', '((w - 15.5) / 2 + cm) / feet').display,
        '((W1 - 15.5) / 2 + cm) / feet',
      );
    });

    test('the corner windows keep left and right apart', () {
      expect(slot('D54F', 'WT_l', '(wl + 6 + cm) / feet').display, '(WT_l + 6 + cm) / feet');
      expect(slot('D54F', 'WT_r', '(wr + 6 + cm) / feet').display, '(WT_r + 6 + cm) / feet');
    });

    test('an estimation margin is shown as plain cm', () {
      // The estimation side keeps a margin per section and names it after the
      // section; a fabricator should just see "cm".
      final FormulaSlot piece = slot('DC30C', 'HL', 'h + cm_DC30C', fabrication: false);
      expect(piece.display, 'HL + cm');
      expect(piece.marginName, 'cm_DC30C');
    });

    test('a section that reads another section\'s margin still shows cm', () {
      // The openable window's D50A pieces read the D50 margin -- that is how
      // the settings are keyed, not a mistake, and the screen should not make
      // a fabricator think about it.
      final FormulaSlot piece = slot('D50A', 'HL', 'h + cm_D50', fabrication: false);
      expect(piece.display, 'HL + cm');
      expect(piece.marginName, 'cm_D50');
    });

    test('renaming does not touch a name that merely contains the same letters', () {
      // "feet" contains no bare h or w, but a careless search and replace for
      // "h" would still find one inside a label like "WH".
      final FormulaSlot piece = slot('D29', 'WH', '(w + cm) / feet');
      expect(piece.display, '(WH + cm) / feet');
      expect(piece.display, contains('feet'));
    });
  });

  group('reading back what was typed', () {
    test('a good edit comes back in the engine\'s names', () {
      final FormulaEdit edit = slot('DC30C', 'HL', '(h + cm) / feet')
          .readDisplay('(HL + 12 + cm) / feet');
      expect(edit.isUsable, isTrue);
      expect(edit.stored, '(h + 12 + cm) / feet');
    });

    test('an estimation edit goes back to the section\'s own margin', () {
      final FormulaEdit edit =
          slot('D50A', 'HL', 'h + cm_D50', fabrication: false).readDisplay('HL + 2 + cm');
      expect(edit.isUsable, isTrue);
      expect(edit.stored, 'h + 2 + cm_D50');
    });

    test('a measurement the piece does not have is refused', () {
      // "w" is not a name this piece may use -- its own label is.
      final FormulaEdit edit =
          slot('DC30C', 'HL', '(h + cm) / feet').readDisplay('(w + cm) / feet');
      expect(edit.isUsable, isFalse);
      expect(edit.problem, contains('w'));
    });

    test('a formula that will not parse is refused with a reason', () {
      final FormulaEdit edit =
          slot('DC30C', 'HL', '(h + cm) / feet').readDisplay('(HL + cm / feet');
      expect(edit.isUsable, isFalse);
      expect(edit.problem, contains('never closed'));
    });

    test('an empty formula is refused', () {
      expect(slot('DC30C', 'HL', '(h + cm) / feet').readDisplay('').isUsable, isFalse);
    });
  });

  group('a round trip changes nothing', () {
    test('shown, read back, and shown again is the same formula', () {
      const List<List<String>> cases = <List<String>>[
        <String>['DC30C', 'HL', '(h + cm) / feet'],
        <String>['D29', 'WT', '((w - 15.5) / 2 + 8.5 + cm) / feet'],
        <String>['M24', 'W1s', '(((w - 20.32) / 2 - 5.08) / 2 + cm) / feet'],
        <String>['D54F', 'WT_l', '(wl + 6 + cm) / feet'],
      ];
      for (final List<String> row in cases) {
        final FormulaSlot piece = slot(row[0], row[1], row[2]);
        final FormulaEdit edit = piece.readDisplay(piece.display);
        expect(edit.isUsable, isTrue, reason: '${row[2]} would not read back');
        expect(edit.stored, row[2], reason: '${row[2]} changed on the round trip');
      }
    });
  });

  group('working out a length', () {
    test('a real sliding window piece', () {
      final FormulaSlot piece = slot('DC30C', 'HL', '(h + cm) / feet');
      final FormulaResult result = piece.lengthFor(<String, double>{
        'h': 220.6,
        'cm': 0.5,
        'feet': 30.48,
      });
      expect(result.isUsable, isTrue);
      expect(result.value, closeTo((220.6 + 0.5) / 30.48, 1e-12));
    });

    test('a window too small for its own deduction is refused, not cut', () {
      final FormulaSlot piece = slot('M24', 'W1', '((w - 15.5) / 2 + cm) / feet');
      final FormulaResult result = piece.lengthFor(<String, double>{
        'w': 10,
        'cm': 0,
        'feet': 30.48,
      });
      expect(result.isUsable, isFalse);
      expect(result.problem, contains('M24 W1'));
    });
  });

  test('the legend names every measurement the box allows', () {
    final FormulaSlot piece = slot('DC30C', 'HL', '(h + cm) / feet');
    expect(piece.allowedDisplayVariables, <String>{'HL', 'cm', 'feet'});
    expect(piece.legend['HL'], contains('height'));
    expect(piece.legend['cm'], contains('margin'));

    final FormulaSlot estimation = slot('DC30C', 'WT', 'w + cm_DC30C', fabrication: false);
    expect(estimation.allowedDisplayVariables, <String>{'WT', 'cm'});
    expect(estimation.legend['WT'], contains('width'));
  });
}
