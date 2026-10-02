import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/optimization_request.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/models/window_size_label.dart';
import 'package:my_app/features/formulas/model/window_sides.dart';

/// A window's size on the cutting list and the glass list: width first, then
/// height, in the unit it was measured in (Hashir, Oct 2026) -- sent to the
/// engine with the half as .5, shown with it as ½ (0½ for half alone).
void main() {
  group('composed for the engine', () {
    test('inches: width first, suter written out, the half as .5', () {
      expect(
        WindowSizeLabel.compose(unit: 'inches', height: '48.35', width: '60'),
        "60'' x 48'' 3.5'''",
      );
      expect(
        WindowSizeLabel.compose(unit: 'inches', height: '34.05', width: '34.3'),
        "34'' 3''' x 34'' 0.5'''",
      );
      expect(
        WindowSizeLabel.compose(unit: 'inches', height: '48.30', width: '60.0'),
        "60'' x 48'' 3'''",
        reason: 'a trailing 0 is no suter',
      );
    });

    test('feet (estimation): feet and inches', () {
      expect(WindowSizeLabel.compose(unit: 'feet', height: '4.9', width: '5'), "5' x 4' 9''");
    });

    test('centimetres: the numbers, and cm once', () {
      expect(WindowSizeLabel.compose(unit: 'cm', height: '120', width: '150.5'), '150.5 x 120 cm');
    });

    test('a corner window: right / left, then the height', () {
      expect(
        WindowSizeLabel.compose(
          unit: 'inches', height: '54.2', width: '30', right: '30', left: '40.15'),
        "30'' / 40'' 1.5''' x 54'' 2'''",
      );
    });

    test('an arch: its rise after the size', () {
      expect(
        WindowSizeLabel.compose(unit: 'inches', height: '48', width: '60', arch: '10.4'),
        "60'' x 48'', arch 10'' 4'''",
      );
    });

    test('never anything the engine splits its labels on', () {
      final String label = WindowSizeLabel.compose(unit: 'cm', height: '1#2', width: '3|4>');
      expect(label.contains('#') || label.contains('|') || label.contains('>'), isFalse);
    });
  });

  group('shown', () {
    test('the half as ½, and half alone as 0½', () {
      expect(WindowSizeLabel.shown("60'' x 48'' 3.5'''"), "60'' x 48'' 3½'''");
      expect(WindowSizeLabel.shown("34'' 3''' x 34'' 0.5'''"), "34'' 3''' x 34'' 0½'''");
      expect(WindowSizeLabel.shown('150.5 x 120 cm'), '150.5 x 120 cm');
    });

    test("an old report's raw height-first numbers are turned round", () {
      expect(WindowSizeLabel.shown('48.35x60'), '60x48.35');
      expect(WindowSizeLabel.shown('54.5x30/40'), '30/40x54.5');
      expect(WindowSizeLabel.shown('54.5x44.5 a:10'), '44.5x54.5 a:10');
    });

    test('a new label is never turned round again', () {
      expect(WindowSizeLabel.shown("60'' x 48''"), "60'' x 48''");
      expect(WindowSizeLabel.shown('150 x 120 cm'), '150 x 120 cm');
    });
  });

  group('sent with every window', () {
    WindowReviewItem item({
      required UnitMode unit,
      String height = '48.35',
      String width = '60',
      SideSizes sides = const SideSizes.empty(),
    }) =>
        WindowReviewItem(
          winNo: 1,
          windowLabel: 'Sliding Window',
          windowCode: 'S_win',
          windowIndex: 1,
          collarIndex: 2,
          unitMode: unit,
          heightValue: height,
          widthValue: width,
          sideSizes: sides,
        );

    test('estimation inches and feet', () {
      final Map<String, Object?> inches = OptimizationWindowRequest.fromReviewItem(
        item(unit: UnitMode.inches), isFabrication: false).toJson();
      expect(inches['sizeLabel'], "60'' x 48'' 3.5'''");
      expect(inches['heightValue'], '48.35', reason: 'the sizes themselves are sent as before');
      final Map<String, Object?> feet = OptimizationWindowRequest.fromReviewItem(
        item(unit: UnitMode.feet, height: '4.9', width: '5'), isFabrication: false).toJson();
      expect(feet['sizeLabel'], "5' x 4' 9''");
    });

    test('estimation cm: labelled in the cm it was typed in, sent in inches', () {
      final Map<String, Object?> json = OptimizationWindowRequest.fromReviewItem(
        item(unit: UnitMode.cm, height: '120', width: '150'), isFabrication: false).toJson();
      expect(json['sizeLabel'], '150 x 120 cm');
      expect(json['unitMode'], 'inches');
    });

    test('fabrication cm and inches', () {
      final Map<String, Object?> cm = OptimizationWindowRequest.fromReviewItem(
        item(unit: UnitMode.feet, height: '120', width: '150'), isFabrication: true).toJson();
      expect(cm['sizeLabel'], '150 x 120 cm');
      final Map<String, Object?> inches = OptimizationWindowRequest.fromReviewItem(
        item(unit: UnitMode.inches), isFabrication: true).toJson();
      expect(inches['sizeLabel'], "60'' x 48'' 3.5'''");
    });

    test('measured side by side: the smaller of each pair, as the engine is sent', () {
      final Map<String, Object?> json = OptimizationWindowRequest.fromReviewItem(
        item(
          unit: UnitMode.feet,
          height: '120',
          width: '150',
          sides: const SideSizes(<String, String>{
            'WT': '150',
            'WB': '149',
            'HL': '120',
            'HR': '121',
          }),
        ),
        isFabrication: true,
      ).toJson();
      expect(json['sizeLabel'], '149 x 120 cm');
      expect(json['widthValue'], '149');
    });
  });
}
