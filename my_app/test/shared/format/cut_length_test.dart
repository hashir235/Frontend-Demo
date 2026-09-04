import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/shared/format/cut_length.dart';

/// A length shown in the wrong unit is a bar cut to the wrong size. These hold
/// the three readings to each other and to the tape.
void main() {
  group('the three readings agree', () {
    test('a foot is a foot', () {
      const CutLength one = CutLength.fromFeet(1);
      expect(one.inFeet, '1 ft');
      expect(one.inCm, '30.5 cm');
      expect(one.inInchSutter, "1' 0'' 0'''");
    });

    test('centimetres in and feet out are the same length', () {
      final CutLength fromCm = CutLength.fromCm(216.9);
      expect(fromCm.feet, closeTo(216.9 / 30.48, 1e-12));
      expect(fromCm.inCm, '216.9 cm');
    });

    test('a real sliding window upright', () {
      // 220.6cm window height, no margin: the DC30C left upright.
      final CutLength piece = CutLength.fromCm(220.6);
      expect(piece.inCm, '220.6 cm');
      expect(piece.inFeet, '7.238 ft');
      // 7.2375 ft = 7ft 2.85in -> 7' 2'' 7'''
      expect(piece.inInchSutter, "7' 2'' 7'''");
    });
  });

  group('reading off a tape', () {
    test('suter counts in eighths', () {
      // Half an inch is four suter.
      expect(CutLength.fromFeet(1 + 0.5 / 12).inInchSutter, "1' 0'' 4'''");
      // A quarter inch is two.
      expect(CutLength.fromFeet(1 + 0.25 / 12).inInchSutter, "1' 0'' 2'''");
    });

    test('it snaps to the half suter the tape actually shows', () {
      // A sixteenth of an inch is half a suter, the finest mark there is.
      expect(CutLength.fromFeet(1 / 16 / 12).inInchSutter, "0' 0'' 0.5'''");
    });

    test('a suter that rounds up carries into the inch', () {
      // Just under a whole inch: must read 1'' 0''', never 0'' 8'''.
      final String reading = CutLength.fromFeet((1 - 1e-9) / 12).inInchSutter;
      expect(reading, "0' 1'' 0'''");
      expect(reading, isNot(contains("8'''")));
    });

    test('an inch that rounds up carries into the foot', () {
      final String reading = CutLength.fromFeet(1 - 1e-9).inInchSutter;
      expect(reading, "1' 0'' 0'''");
      expect(reading, isNot(contains("12''")));
    });

    test('a negative length reads as nothing rather than nonsense', () {
      expect(CutLength.fromFeet(-3).inInchSutter, "0' 0'' 0'''");
    });
  });

  group('written the way a tape is read', () {
    test('trailing zeros are dropped', () {
      expect(const CutLength.fromFeet(7).inFeet, '7 ft');
      expect(const CutLength.fromFeet(7.1).inFeet, '7.1 ft');
      expect(const CutLength.fromFeet(7.116).inFeet, '7.116 ft');
    });

    test('all three, with the formula\'s own unit first', () {
      final CutLength piece = CutLength.fromCm(216.9);
      expect(piece.threeWays(centimetresFirst: true), startsWith('216.9 cm'));
      expect(piece.threeWays(centimetresFirst: false), startsWith('7.116 ft'));
      for (final bool cmFirst in <bool>[true, false]) {
        final String line = piece.threeWays(centimetresFirst: cmFirst);
        expect(line, contains('cm'));
        expect(line, contains('ft'));
        expect(line, contains("''"));
      }
    });
  });
}
