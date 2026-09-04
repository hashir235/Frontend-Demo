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
    // The cutting margin and the change to feet are the same on every piece
    // and are not a workshop's choice, so they are not shown. What is left is
    // the arithmetic somebody actually decided.
    test('a height piece reads as its label, without the plumbing', () {
      expect(slot('DC30C', 'HL', '(h + cm) / feet').display, 'HL');
      expect(slot('DC30C', 'HR', '(h - 4.2 + cm) / feet').display, 'HR - 4.2');
    });

    test('a width piece reads as its label', () {
      expect(slot('DC30C', 'WT', '(w + cm) / feet').display, 'WT');
      expect(
        slot('M24', 'W1', '((w - 15.5) / 2 + cm) / feet').display,
        '(W1 - 15.5) / 2',
      );
    });

    test('the corner windows keep left and right apart', () {
      expect(slot('D54F', 'WT_l', '(wl + 6 + cm) / feet').display, 'WT_l + 6');
      expect(slot('D54F', 'WT_r', '(wr + 6 + cm) / feet').display, 'WT_r + 6');
    });

    test('the estimation side hides its per-section margin too', () {
      final FormulaSlot piece = slot('DC30C', 'HL', 'h + cm_DC30C', fabrication: false);
      expect(piece.display, 'HL');
      expect(piece.marginName, 'cm_DC30C');
    });

    test('a section that reads another section\'s margin still hides it', () {
      // The openable window's D50A pieces read the D50 margin -- that is how
      // the settings are keyed, not a mistake, and the screen should not make
      // a fabricator think about it.
      final FormulaSlot piece = slot('D50A', 'HL', 'h + cm_D50', fabrication: false);
      expect(piece.display, 'HL');
      expect(piece.marginName, 'cm_D50');
    });

    test('a formula with no margin at all is shown whole', () {
      // The round arch's rib: no margin, no conversion, nothing to take off.
      final FormulaSlot piece = slot('D51F', 'Arch', 'ar + 1', fabrication: false);
      expect(piece.display, 'Arch + 1');
      expect(piece.hasHiddenEnvelope, isFalse);
    });

    test('knows whether anything is hidden behind the formula', () {
      expect(slot('DC30C', 'HL', '(h + cm) / feet').hasHiddenEnvelope, isTrue);
      expect(
        slot('DC30C', 'HL', 'h + cm_DC30C', fabrication: false).hasHiddenEnvelope,
        isTrue,
      );
      expect(
        slot('D51F', 'Arch', 'ar + 1', fabrication: false).hasHiddenEnvelope,
        isFalse,
      );
    });

    test('renaming does not touch a name that merely contains the same letters', () {
      // A careless search and replace for "h" would find one inside a label
      // like "WH", and one inside "feet" for "e".
      final FormulaSlot piece = slot('D29', 'WH', '(w - 3 + cm) / feet');
      expect(piece.display, 'WH - 3');
    });
  });

  group('reading back what was typed', () {
    test('a good edit is wrapped back up in the plumbing', () {
      final FormulaEdit edit =
          slot('DC30C', 'HL', '(h + cm) / feet').readDisplay('HL + 12');
      expect(edit.isUsable, isTrue);
      expect(edit.stored, '(h + 12 + cm) / feet');
    });

    test('an estimation edit goes back to the section\'s own margin', () {
      final FormulaEdit edit =
          slot('D50A', 'HL', 'h + cm_D50', fabrication: false).readDisplay('HL + 2');
      expect(edit.isUsable, isTrue);
      expect(edit.stored, 'h + 2 + cm_D50');
    });

    test('a measurement the piece does not have is refused', () {
      // "w" is not a name this piece may use -- its own label is.
      final FormulaEdit edit =
          slot('DC30C', 'HL', '(h + cm) / feet').readDisplay('w + 6');
      expect(edit.isUsable, isFalse);
      expect(edit.problem, contains('w'));
    });

    test('the margin cannot be named, so it cannot be added twice', () {
      final FormulaEdit edit =
          slot('DC30C', 'HL', '(h + cm) / feet').readDisplay('HL + cm');
      expect(edit.isUsable, isFalse);
      expect(edit.problem, contains('cm'));
    });

    test('the feet conversion cannot be named either', () {
      final FormulaEdit edit =
          slot('DC30C', 'HL', '(h + cm) / feet').readDisplay('HL / feet');
      expect(edit.isUsable, isFalse);
      expect(edit.problem, contains('feet'));
    });

    test('a formula that will not parse is refused with a reason', () {
      final FormulaEdit edit =
          slot('DC30C', 'HL', '(h + cm) / feet').readDisplay('(HL + 6');
      expect(edit.isUsable, isFalse);
      expect(edit.problem, contains('never closed'));
    });

    test('an empty formula is refused', () {
      expect(slot('DC30C', 'HL', '(h + cm) / feet').readDisplay('').isUsable, isFalse);
    });
  });

  group('a round trip changes nothing', () {
    test('shown, read back, and shown again is the same formula', () {
      // Every one of these is a real shape from the shipped catalogue. What
      // matters is that hiding the margin and the conversion, then putting
      // them back, lands on exactly the formula that was stored -- a job
      // opened and saved untouched must cut identically.
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

    test('and the same on the estimation side', () {
      const List<List<String>> cases = <List<String>>[
        <String>['DC30C', 'HL', 'h + cm_DC30C'],
        <String>['M24', 'W1', 'w / 2 + cm_M24'],
        <String>['D51F', 'Arch', 'ar + 1'],
      ];
      for (final List<String> row in cases) {
        final FormulaSlot piece = slot(row[0], row[1], row[2], fabrication: false);
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

    test('the size actually cut leaves the saw\'s allowance out', () {
      // The optimizer is given the margin so it can leave the blade room; the
      // cutting list takes it off again. A fabricator reads the second number,
      // and setting a formula against the first would be wrong by one blade
      // width on every piece.
      final FormulaSlot piece = slot('DC30C', 'HL', '(h + cm) / feet');
      const Map<String, double> window = <String, double>{
        'h': 220.6,
        'cm': 0.5,
        'feet': 30.48,
      };
      expect(piece.lengthFor(window).value, closeTo((220.6 + 0.5) / 30.48, 1e-12));
      expect(piece.cutLengthFor(window).value, closeTo(220.6 / 30.48, 1e-12));
    });

    test('estimation keeps its margin in, as its cutting list does', () {
      // There the margin is an allowance on what to buy, not where to cut, and
      // the report shows it. Hiding it here would disagree with that.
      final FormulaSlot piece = slot('DC30C', 'HL', 'h + cm_DC30C', fabrication: false);
      const Map<String, double> window = <String, double>{'h': 7.2, 'cm_DC30C': 0.07};
      expect(piece.cutLengthFor(window).value, closeTo(7.27, 1e-12));
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

  test('the box allows the piece\'s own measurement and nothing else', () {
    final FormulaSlot piece = slot('DC30C', 'HL', '(h + cm) / feet');
    expect(piece.allowedDisplayVariables, <String>{'HL'});
    expect(piece.legend, <String, String>{'HL': 'window height (cm)'});

    final FormulaSlot estimation = slot('DC30C', 'WT', 'w + cm_DC30C', fabrication: false);
    expect(estimation.allowedDisplayVariables, <String>{'WT'});
    expect(estimation.legend, <String, String>{'WT': 'window width (ft)'});
  });
}
