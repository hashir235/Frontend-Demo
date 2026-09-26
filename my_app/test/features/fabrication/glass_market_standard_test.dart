import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/fabrication/models/glass_sheet_optimization.dart';

/// Glass is sold by the market standard: each side is taken up to the next
/// 3 inches up to 24, then to the next 6. A side exactly on a step stays; even
/// half a suter over takes the next step.
void main() {
  const double halfSuter = 1 / 16;

  group('one side, at the market standard', () {
    for (final (double tape, double market, String why) in <(double, double, String)>[
      (14, 15, '14 is taken up to 15'),
      (15, 15, 'exactly on a step, it stays'),
      (15 + halfSuter, 18, 'half a suter over takes the next step'),
      (1, 3, 'the smallest step is 3'),
      (3, 3, '3 stays 3'),
      (3 + halfSuter, 6, 'past 3 is 6'),
      (21.5, 24, 'up to 24 in threes'),
      (24, 24, '24 stays 24'),
      (24 + halfSuter, 30, 'past 24 the step is 6'),
      (30, 30, '30 stays 30'),
      (30 + halfSuter, 36, 'then 36'),
      (43, 48, 'and on in sixes'),
      (60, 60, 'on a step past 24, it stays'),
    ]) {
      test('$tape in -> $market in: $why', () {
        expect(marketSideInches(tape), market);
      });
    }

    test('a side reached through cm stays on its step', () {
      // 38.1 cm / 2.54 is 15.000000000000002 in floating point.
      expect(marketSideInches(38.1 / 2.54), 15);
      // 57.15 cm / 2.54 is 22.499999999999996.
      expect(marketSideInches(57.15 / 2.54), 24);
    });

    test('nothing measures nothing', () {
      expect(marketSideInches(0), 0);
      expect(marketSideInches(-5), 0);
    });
  });

  group('a piece, and a sheet of pieces', () {
    GlassSheetPlacement piece({
      required double width,
      required double height,
      bool rotated = false,
    }) =>
        GlassSheetPlacement(
          id: 'p',
          label: '',
          pieceNo: 1,
          x: 0,
          y: 0,
          width: width,
          height: height,
          glassSizeDisplay: '',
          rotated: rotated,
        );

    test('each side is stepped, then multiplied', () {
      final GlassSheetPlacement p = piece(width: 14, height: 20);
      expect(p.mathArea, 280);
      expect(p.marketWidth, 15);
      expect(p.marketHeight, 21);
      expect(p.marketArea, 315);
    });

    test('a piece laid on its side keeps its own width and height', () {
      // Placed 20 wide and 14 high: the glass itself is 14 by 20.
      final GlassSheetPlacement p = piece(width: 20, height: 14, rotated: true);
      expect(p.marketWidth, 15);
      expect(p.marketHeight, 21);
      expect(p.marketArea, 315);
    });

    test('a sheet adds up its pieces at the market standard', () {
      final GlassSheetLayout sheet = GlassSheetLayout.fromJson(<String, dynamic>{
        'sheetNo': 1,
        'placements': <Map<String, dynamic>>[
          <String, dynamic>{'width': 14, 'height': 20, 'rotated': false},
          <String, dynamic>{'width': 24.0625, 'height': 30, 'rotated': false},
        ],
      });
      // 15 x 21 = 315, and 30 x 30 = 900.
      expect(sheet.marketUsedArea, 1215);
    });
  });
}
