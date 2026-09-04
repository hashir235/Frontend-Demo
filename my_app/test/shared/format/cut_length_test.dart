import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/shared/format/cut_length.dart';

/// A cut size is read off a tape, and a tape does not have decimals on it.
/// These hold the three readings to what a workshop would actually call out --
/// including the two carries, which are the only places this can go quietly
/// wrong.
void main() {
  group('the three readings of one bar', () {
    test('a real sliding window upright', () {
      // 216.4 cm is 85.1968... inches: 85 whole, and 0.1968 x 8 = 1.57 suter,
      // which is 1.5 on a tape.
      final CutLength length = CutLength.fromCm(216.4);
      expect(length.inCm, '216.4');
      expect(length.inInchSuter, "85'' 1.5'''");
      expect(length.inFeetInchSuter, "7' 1'' 1.5'''");
    });

    test('feet and inches are two readings of the same bar, not one', () {
      // The distinction that matters: a shop working in inches counts 85
      // inches and never mentions feet; one working in feet says seven feet
      // one. Reading the second to somebody who works in the first is how a
      // bar gets cut at seven inches.
      final CutLength length = CutLength.fromCm(216.4);
      expect(length.inInchSuter, isNot(equals(length.inFeetInchSuter)));
      // The inch reading never mentions feet, and counts every inch there is.
      expect(length.inInchSuter, "85'' 1.5'''");
      expect(length.inInchSuter, isNot(contains("'''85")));
      // The feet reading splits the same 85 inches into 7 feet and 1 inch.
      expect(length.inFeetInchSuter, "7' 1'' 1.5'''");
    });

    test('a short piece, where feet reads as zero', () {
      // 20 cm = 7.874 inches: 7 whole, 0.874 x 8 = 6.99 suter -> 7.
      final CutLength length = CutLength.fromCm(20);
      expect(length.inInchSuter, "7'' 7'''");
      expect(length.inFeetInchSuter, "0' 7'' 7'''");
    });
  });

  group('the carries', () {
    test('a hair under a whole inch reads as the next inch, not eight suter', () {
      // Nobody has an eight-suter mark to cut to.
      final CutLength length = CutLength.fromFeet((10 + 7.96 / 8) / 12);
      expect(length.inInchSuter, "11'' 0'''");
    });

    test('a hair under a whole foot carries all the way', () {
      final CutLength length = CutLength.fromFeet((11 + 7.96 / 8) / 12);
      expect(length.inInchSuter, "12'' 0'''");
      expect(length.inFeetInchSuter, "1' 0'' 0'''");
    });

    test('suter snaps to the half, which is the finest mark there is', () {
      // 0.3 of an inch is 2.4 suter, which reads as 2.5.
      final CutLength length = CutLength.fromFeet(5.3 / 12);
      expect(length.inInchSuter, "5'' 2.5'''");
    });

    test('a whole number of suter has no needless decimal', () {
      final CutLength length = CutLength.fromFeet((6 + 4 / 8) / 12);
      expect(length.inInchSuter, "6'' 4'''");
    });
  });

  group('centimetres', () {
    test('to the millimetre a tape can show, and no further', () {
      expect(CutLength.fromCm(216.44).inCm, '216.4');
      expect(CutLength.fromCm(216.46).inCm, '216.5');
    });

    test('a whole number keeps no trailing zero', () {
      expect(CutLength.fromCm(216).inCm, '216');
      expect(CutLength.fromCm(216.0).inCm, '216');
    });
  });

  group('the order they are read in', () {
    test('centimetres lead where the formulas are written in centimetres', () {
      final List<CutReading> readings =
          CutLength.fromCm(216.4).readings(centimetresFirst: true);
      expect(readings.map((CutReading r) => r.unit), <String>['cm', 'ft', 'in']);
    });

    test('and follow where they are not', () {
      final List<CutReading> readings =
          CutLength.fromCm(216.4).readings(centimetresFirst: false);
      expect(readings.map((CutReading r) => r.unit), <String>['ft', 'in', 'cm']);
    });
  });

  test('a length of nothing does not read as gibberish', () {
    expect(CutLength.fromCm(0).inInchSuter, "0'' 0'''");
    expect(CutLength.fromFeet(-1).inInchSuter, "0'' 0'''");
  });
}
