import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/model/formula_expression.dart';
import 'package:my_app/features/formulas/model/formula_inches.dart';
import 'package:my_app/features/formulas/model/formula_slot.dart';

/// Formulas read and written in inches and suter, for a window measured that
/// way. The inch reading is only a lens: what is stored stays centimetres or
/// feet, and a number nobody changed must come back exactly as it was.
void main() {
  FormulaSlot fabrication(String stored, {String label = 'HL'}) => FormulaSlot(
        section: 'DC30C',
        label: label,
        stored: stored,
        isFabrication: true,
      );

  FormulaSlot glass(String stored, {String label = 'W'}) => FormulaSlot(
        section: 'glass1',
        label: label,
        stored: stored,
        isFabrication: true,
        measuresInCentimetres: true,
      );

  FormulaSlot estimation(String stored, {String label = 'H'}) => FormulaSlot(
        section: 'M23',
        label: label,
        stored: stored,
        isFabrication: false,
      );

  group('a length on the tape', () {
    test('reads as inches and suter, the half as ½', () {
      expect(const InchLength(0).text, "0''");
      expect(const InchLength(16).text, "1''");
      expect(InchLength.of(inches: 6).text, "6''");
      expect(InchLength.of(inches: 1, suter: 5).text, "1'' 5'''");
      expect(InchLength.of(inches: 1, suter: 2.5).text, "1'' 2½'''");
      expect(InchLength.of(suter: 3).text, "3'''");
      // Half a suter alone reads 0½, as it does in every list of sizes.
      expect(InchLength.of(suter: 0.5).text, "0½'''");
      expect(InchLength.of(inches: 6, suter: 0.5).text, "6'' 0½'''");
    });

    test('the nearest mark, carried into the next inch', () {
      // 4.2 cm is 1.6535 inches: 1'' and 5.23 suter, nearest 1'' 5'''.
      expect(InchLength.nearest(4.2 / 2.54).text, "1'' 5'''");
      // A hair under 8 inches is 8 inches, never 7'' 8'''.
      expect(InchLength.nearest(7.999).text, "8''");
    });

    test('steps by half a suter, never below nothing', () {
      expect(InchLength.of(inches: 1, suter: 7.5).step(1).text, "2''");
      expect(const InchLength(0).step(-1).text, "0''");
    });
  });

  group('showing a formula in inches', () {
    test('lengths in inches, counts left as they are', () {
      final InchFormula inches = InchFormula.of(
        fabrication('(((w - 20.32) / 2 - 5.08) / 2 + 8.5 + cm) / feet', label: 'W1'),
      )!;
      // 20.32 cm is exactly 8'' and 5.08 cm exactly 2''; 8.5 cm is 3.35'',
      // nearest 3'' 3'''. The divisions stay plain numbers.
      expect(inches.text, "((W1 - 8'') / 2 - 2'') / 2 + 3'' 3'''");
      final List<InchLengthPart> lengths =
          inches.parts.whereType<InchLengthPart>().toList();
      expect(lengths.map((InchLengthPart p) => p.approximate), <bool>[false, false, true]);
      expect(inches.hasApproximate, isTrue);
    });

    test('a formula that is only the measurement has nothing to convert', () {
      final InchFormula inches = InchFormula.of(fabrication('(h + cm) / feet'))!;
      expect(inches.text, 'HL');
      expect(inches.parts.single, isA<InchMeasurement>());
      expect(inches.hasApproximate, isFalse);
    });

    test('glass is centimetres too', () {
      expect(InchFormula.of(glass('w - 5.08'))!.text, "W - 2''");
    });

    test('estimation is in feet: a foot is 12 inches', () {
      expect(InchFormula.of(estimation('ar + 1', label: 'Arch'))!.text, "Arch + 12''");
      expect(InchFormula.of(estimation('w / 2 + cm_M24', label: 'W1'))!.text, 'W1 / 2');
    });

    test('a measurement times a measurement has no reading in inches', () {
      expect(InchFormula.of(fabrication('(h * h + cm) / feet')), isNull);
      expect(InchFormula.of(fabrication('(100 / h + cm) / feet')), isNull);
    });
  });

  group('every shipped formula', () {
    final Map<String, dynamic> catalogue = jsonDecode(
      File('assets/formulas/catalogue.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final List<String> formulas = (catalogue['formulas'] as List<dynamic>).cast<String>();

    FormulaSlot slotFor(String stored) {
      final bool isEstimation = stored.contains('cm_') || stored.startsWith('ar ');
      final bool isGlass = !isEstimation && !stored.contains('feet');
      final FormulaSlot plain = FormulaSlot(
        section: isGlass ? 'glass1' : 'X',
        label: 'L',
        stored: stored,
        isFabrication: !isEstimation,
        measuresInCentimetres: isGlass,
      );
      return FormulaSlot(
        section: plain.section,
        label: plain.dimension == 'ar' ? 'Arch' : 'L',
        stored: stored,
        isFabrication: !isEstimation,
        measuresInCentimetres: isGlass,
      );
    }

    test('is stored the way the app writes it', () {
      for (final String stored in formulas) {
        expect(FormulaExpression.parse(stored).toString(), stored);
      }
    });

    test('reads in inches, and reads back to exactly what was stored', () {
      expect(formulas, hasLength(183));
      for (final String stored in formulas) {
        final FormulaSlot slot = slotFor(stored);
        final InchFormula? inches = InchFormula.of(slot);
        expect(inches, isNotNull, reason: stored);
        final InchReading back = inches!.read(inches.text);
        expect(back.edit.problem, isNull, reason: '$stored -> ${inches.text}');
        expect(back.edit.stored, stored, reason: '$stored -> ${inches.text}');
        expect(back.canonical, inches.text, reason: stored);
      }
    });

    test('changing one number leaves every other number exact', () {
      for (final String stored in formulas) {
        final FormulaSlot slot = slotFor(stored);
        final InchFormula inches = InchFormula.of(slot)!;
        final List<InchLengthPart> lengths =
            inches.parts.whereType<InchLengthPart>().toList();
        if (lengths.length < 2) continue;

        final InchLengthPart first = lengths.first;
        final String changed =
            inches.replaceLength(inches.text, 0, first.length.step(1));
        final InchReading back = inches.read(changed);
        expect(back.isUsable, isTrue, reason: changed);

        final List<double> before = _numbers(stored);
        final List<double> after = _numbers(back.edit.stored!);
        expect(after, hasLength(before.length), reason: stored);
        final int moved = before.indexOf(first.kept!);
        for (int i = 0; i < before.length; i++) {
          if (i == moved) continue;
          expect(after[i], before[i], reason: '$stored -> ${back.edit.stored}');
        }
        // The one that was changed is exactly the mark it was set to.
        final double inchesNow = (first.length.sixteenths + 1) / 16;
        final double expected = slot.isFabrication ? inchesNow * 2.54 : inchesNow / 12;
        expect(after[moved], closeTo(expected, 1e-6), reason: stored);
      }
    });
  });

  group('reading a formula typed in inches', () {
    final FormulaSlot hl = fabrication('(h - 4.2 + cm) / feet');

    String? stored(String typed, [FormulaSlot? slot]) =>
        InchFormula.of(slot ?? hl)!.read(typed).edit.stored;

    String? problem(String typed, [FormulaSlot? slot]) =>
        InchFormula.of(slot ?? hl)!.read(typed).edit.problem;

    test('a number left at its mark keeps its exact value', () {
      expect(InchFormula.of(hl)!.text, "HL - 1'' 5'''");
      // Typed out again, spaced differently: still exactly 4.2.
      expect(stored("HL-1''5'''"), '(h - 4.2 + cm) / feet');
    });

    test('a number changed is exactly the mark it was set to', () {
      // 1'' 6''' is 1.75 inches: 4.445 cm.
      expect(stored("HL - 1'' 6'''"), '(h - 4.445 + cm) / feet');
      expect(stored("HL - 2''"), '(h - 5.08 + cm) / feet');
      expect(stored("HL - 3'''"), '(h - 0.9525 + cm) / feet');
      expect(stored("HL - 1'' 5½'''"), '(h - 4.28625 + cm) / feet');
      expect(stored("HL - 0½'''"), '(h - 0.15875 + cm) / feet');
      expect(stored("HL - ½'''"), '(h - 0.15875 + cm) / feet');
      expect(stored("HL - 1'' 5.5'''"), '(h - 4.28625 + cm) / feet');
    });

    test('the way a phone types the marks is read the same', () {
      // The parser sees what the box has already tidied; a space before the
      // marks is allowed.
      expect(stored("HL - 2 ''"), '(h - 5.08 + cm) / feet');
    });

    test('counts stay counts', () {
      final FormulaSlot wt = fabrication('((w - 15.5) / 2 + 8.5 + cm) / feet', label: 'WT');
      final InchFormula inches = InchFormula.of(wt)!;
      expect(inches.text, "(WT - 6'' 1''') / 2 + 3'' 3'''");
      expect(inches.read(inches.text).edit.stored, '((w - 15.5) / 2 + 8.5 + cm) / feet');
      expect(
        inches.read("(WT - 6'' 1''') / 3 + 3'' 3'''").edit.stored,
        '((w - 15.5) / 3 + 8.5 + cm) / feet',
      );
    });

    test('estimation keeps feet', () {
      final FormulaSlot arch = estimation('ar + 1', label: 'Arch');
      expect(stored("Arch + 12''", arch), 'ar + 1');
      expect(stored("Arch + 13''", arch), 'ar + 1.08333333');
      final FormulaSlot w1 = estimation('w / 2 + cm_M24', label: 'W1');
      expect(stored("W1 / 2 + 1''", w1), 'w / 2 + 0.08333333 + cm_M24');
    });

    test('a length without its marks is refused, and told how to write it', () {
      expect(problem('HL - 4'), contains("4'' for inches, or 4''' for suter"));
      expect(problem('HL - 4.2'), contains('needs its marks'));
    });

    test('a count with marks is refused', () {
      final FormulaSlot wt = fabrication('((w - 15.5) / 2 + cm) / feet', label: 'WT');
      expect(problem("(WT - 6'') / 2''", wt), contains('plain number with no marks'));
    });

    test('suter is 0 to 7½, in halves', () {
      expect(problem("HL - 8'''"), contains("Write 1''."));
      expect(problem("HL - 10'''"), contains("Write 1''\u00A02'''."));
      expect(problem("HL - 2.3'''"), contains("suter goes in halves: 2''' or 2½'''"));
    });

    test('inches are whole; the rest is suter', () {
      expect(problem("HL - 1.5''"), contains("Write 1''\u00A04'''."));
      expect(problem("HL - 1½''"), contains("Write 1''\u00A04'''."));
    });

    test('one mark is feet, four is too many', () {
      expect(problem("HL - 1'"), contains('one mark is feet'));
      expect(problem("HL - 1''''"), contains('Too many marks'));
    });

    test('an inch followed by another number wants that to be its suter', () {
      expect(problem("HL - 1'' 5"), contains("After 1'' comes the suter"));
      expect(problem("HL - 1'' 5''"), contains("1''\u00A05'''"));
    });

    test('½ without suter marks is refused', () {
      expect(problem('HL - 2½'), contains('½ is half a suter'));
    });

    test('a measurement this piece does not have is refused', () {
      expect(problem("w - 1''"), 'w is not a measurement this window has.');
    });

    test('a measurement times a measurement is refused', () {
      expect(problem('HL * HL'), contains('does not come out as a length'));
      expect(problem("100'' / HL"), contains('does not come out as a length'));
    });

    test('broken arithmetic is refused as it is in centimetres', () {
      expect(problem("(HL - 1''"), contains('never closed'));
      expect(problem(''), 'This formula is empty.');
      expect(problem("HL - ''"), contains('needs a number in front of it'));
    });

    test('two plain numbers multiplied: the marked one is the length', () {
      expect(stored("HL - 2 * 1''"), '(h - 2 * 2.54 + cm) / feet');
      expect(stored("HL - 1'' * 2"), '(h - 2.54 * 2 + cm) / feet');
    });

    test('a doubled measurement is still a length', () {
      expect(stored("HL * 2 - 1''"), '(h * 2 - 2.54 + cm) / feet');
      expect(stored("2 * HL - 1''"), '(2 * h - 2.54 + cm) / feet');
    });
  });

  group('one number set from its own box', () {
    test('replaces just that number, and writes the formula tidily', () {
      final InchFormula inches = InchFormula.of(
        fabrication('((w - 15.5) / 2 + 8.5 + cm) / feet', label: 'WT'),
      )!;
      final String moved = inches.replaceLength(
        "(WT-6''1''')/2+3''3'''",
        1,
        InchLength.of(inches: 3, suter: 4),
      );
      expect(moved, "(WT - 6'' 1''') / 2 + 3'' 4'''");
      // 15.5 kept exactly; 3'' 4''' is 3.5 inches: 8.89 cm.
      expect(inches.read(moved).edit.stored, '((w - 15.5) / 2 + 8.89 + cm) / feet');
    });

    test('set back to its own mark, it is its exact value again', () {
      final InchFormula inches = InchFormula.of(fabrication('(h - 4.2 + cm) / feet'))!;
      final String away = inches.replaceLength(inches.text, 0, InchLength.of(inches: 2));
      final String back = inches.replaceLength(away, 0, InchLength.of(inches: 1, suter: 5));
      expect(back, inches.text);
      expect(inches.read(back).edit.stored, '(h - 4.2 + cm) / feet');
      final InchLengthPart part =
          inches.read(back).parts!.whereType<InchLengthPart>().single;
      expect(part.approximate, isTrue);
      expect(part.kept, 4.2);
    });
  });

  group('the unit behind the inches', () {
    test('says a stored value plainly', () {
      const FormulaInchUnit cm = FormulaInchUnit(isFabrication: true);
      const FormulaInchUnit ft = FormulaInchUnit(isFabrication: false);
      expect(cm.say(15.5), '15.5 cm');
      expect(cm.say(20.32), '20.32 cm');
      expect(ft.say(1), '1 ft');
    });

    test('marks convert to clean decimals', () {
      const FormulaInchUnit cm = FormulaInchUnit(isFabrication: true);
      for (int s = 0; s < 16 * 120; s++) {
        final double value = cm.valueOf(InchLength(s));
        expect(cm.isOnTheMark(value), isTrue);
        expect(cm.nearest(value).sixteenths, s);
        expect(value.toString().split('.').last.length, lessThanOrEqualTo(5));
      }
      const FormulaInchUnit ft = FormulaInchUnit(isFabrication: false);
      for (int s = 0; s < 16 * 120; s++) {
        final double value = ft.valueOf(InchLength(s));
        expect(ft.isOnTheMark(value), isTrue);
        expect(ft.nearest(value).sixteenths, s);
      }
    });
  });
}

/// Every number in a stored formula, in the order written.
List<double> _numbers(String stored) {
  return FormulaRoles.numbersInOrder(FormulaExpression.parse(stored))
      .map((FormulaNumber n) => n.value)
      .toList();
}
