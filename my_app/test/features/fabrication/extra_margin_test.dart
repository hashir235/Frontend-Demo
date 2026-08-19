import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/fabrication/models/glass_sheet_optimization.dart';
import 'package:my_app/features/fabrication/presentation/extra_margin_field.dart';

/// The extra margin lets a layout run slightly past the real sheet instead of
/// opening a second one, on the understanding that every piece is cut a little
/// smaller to take it up. Both halves of that have to survive the trip from
/// the optimizer to the screen: how much it overshot, and that it did at all.
void main() {
  group('ShopLength', () {
    test('turns inches and suter into decimal inches', () {
      expect(const ShopLength(inches: 1, suter: 2).asInches, closeTo(1.25, 1e-9));
      expect(const ShopLength(inches: 0, suter: 2).asInches, closeTo(0.25, 1e-9));
      expect(const ShopLength(inches: 2, suter: 0).asInches, closeTo(2.0, 1e-9));
    });

    test('half suter is carried, since the tape has it', () {
      expect(const ShopLength(suter: 7.5).asInches, closeTo(0.9375, 1e-9));
    });

    test('nothing entered means no margin at all', () {
      expect(const ShopLength().isZero, isTrue);
      expect(const ShopLength().asInches, 0);
      // A margin of zero must leave the optimizer exactly as it was.
      expect(const ShopLength(inches: 0, suter: 0).asInches, 0);
    });

    test('reads back the way the shop says it', () {
      expect(const ShopLength(inches: 1, suter: 2).display, "1'' 2'''");
      expect(const ShopLength(inches: 0, suter: 3).display, "3'''");
      expect(const ShopLength(inches: 2).display, "2''");
      expect(const ShopLength().display, '0');
    });
  });

  group('GlassSheetLayout margin reporting', () {
    Map<String, dynamic> sheetJson(Map<String, dynamic> extra) => <String, dynamic>{
      'sheetNo': 1,
      'width': 84.0,
      'height': 145.0,
      'widthDisplay': "84''",
      'heightDisplay': "145''",
      'usedArea': 100.0,
      'wasteArea': 10.0,
      'wastagePercentage': 5.0,
      'placements': <dynamic>[],
      'wasteRects': <dynamic>[],
      ...extra,
    };

    test('carries the overshoot through', () {
      final GlassSheetLayout sheet = GlassSheetLayout.fromJson(
        sheetJson(<String, dynamic>{
          'nominalWidth': 84.0,
          'nominalHeight': 144.0,
          'usesExtraMargin': true,
          'marginOverHeight': 0.5,
          'marginOverHeightDisplay': "0'' 4'''",
        }),
      );

      expect(sheet.usesExtraMargin, isTrue);
      expect(sheet.nominalHeight, 144.0);
      expect(sheet.marginOverHeight, 0.5);
      expect(sheet.marginOverHeightDisplay, "0'' 4'''");
      // Width was untouched, so nothing should suggest it overshot.
      expect(sheet.marginOverWidth, 0);
    });

    test('a sheet that never reached past is not flagged', () {
      final GlassSheetLayout sheet = GlassSheetLayout.fromJson(
        sheetJson(<String, dynamic>{
          'nominalWidth': 84.0,
          'nominalHeight': 144.0,
          'usesExtraMargin': false,
        }),
      );

      // Allowing a margin must not put a warning on every sheet -- a warning
      // that shows when nothing is wrong is one people learn to ignore.
      expect(sheet.usesExtraMargin, isFalse);
      expect(sheet.marginOverHeight, 0);
      expect(sheet.marginOverWidth, 0);
    });

    test('an older server, which sends none of this, reports no overshoot', () {
      final GlassSheetLayout sheet = GlassSheetLayout.fromJson(sheetJson(<String, dynamic>{}));

      expect(sheet.usesExtraMargin, isFalse);
      // Falls back to the laid-out size rather than zero, so the drawing has
      // a sane edge to work from.
      expect(sheet.nominalWidth, 84.0);
      expect(sheet.nominalHeight, 145.0);
    });
  });
}
