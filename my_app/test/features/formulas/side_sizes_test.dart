import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/optimization_api_client.dart';
import 'package:my_app/features/estimation/data/optimization_repository.dart';
import 'package:my_app/features/estimation/models/cutting_report.dart';
import 'package:my_app/features/estimation/models/optimization_request.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_book_loader.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';
import 'package:my_app/features/formulas/model/window_sides.dart';
import 'package:my_app/features/settings/data/fabrication_settings_repository.dart';
import 'package:my_app/features/settings/models/fabrication_settings.dart';

/// A window measured one side at a time.
///
/// A wall is not square: the top of an opening can be an inch wider than its
/// bottom. The frame is cut to what was measured, side by side; everything
/// inside it is cut to the smaller of each pair, because a sash cut to the
/// wider edge does not go in. These run against the real shipped catalogue --
/// what matters is that the formulas Quick AL actually carries are split
/// frame from inner correctly, not that a fixture can be.
void main() {
  late FormulaCatalogue catalogue;

  setUpAll(() {
    catalogue = FormulaCatalogue.fromJson(
      jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  FormulaBook book() => FormulaBook(catalogue, FormulaOverrides.empty());

  FormulaWindowKey keyFor(
    String window, {
    int collar = 2,
    int? lock = 1,
    String rubber = 'F',
    bool addBottom = false,
    bool addTee = false,
  }) {
    return FormulaWindowKey.of(
      context: 'fabrication',
      appWindowCode: window,
      dimensions: catalogue.dimensionsFor(
        'fabrication/${window == 'Single_Door' ? 'D_win' : window == 'SCF_win' ? 'SC_win' : window}',
      ),
      collarIndex: collar,
      lockType: lock,
      rubberType: rubber,
      addBottom: addBottom,
      addTee: addTee,
    )!;
  }

  group('which part of a window is its frame', () {
    test('the profiles the collar decides, and no others', () {
      // DC30 and DC26 come in a C and an F and change with the collar; the
      // sashes and the beading never do.
      final Set<String> frame = catalogue.frameSectionsFor('fabrication/S_win');
      expect(frame, <String>{'DC26C', 'DC26F', 'DC30C', 'DC30F'});
      expect(frame, isNot(contains('D29')));
      expect(frame, isNot(contains('M23')));
      expect(frame, isNot(contains('M24')));
      expect(frame, isNot(contains('M28')));
    });

    test('every window has one, and it is never the whole window', () {
      for (final String window in <String>[
        'S_win',
        'SM_win',
        'SG_win',
        'SGM_win',
        'F_win',
        'O_win',
        'FC_win',
        'SC_win',
        'SCM_win',
        'D_win',
      ]) {
        final Set<String> frame = catalogue.frameSectionsFor('fabrication/$window');
        expect(frame, isNotEmpty, reason: window);
      }
    });

    test('a window has the sides its frame has', () {
      // Four for an ordinary window.
      expect(
        catalogue.frameSideLabelsFor(keyFor('S_win')),
        <String>{'WT', 'WB', 'HL', 'HR'},
      );
      // Three for a door: a door has no bottom frame.
      expect(
        catalogue.frameSideLabelsFor(keyFor('Single_Door', collar: 2)),
        <String>{'WT', 'HL', 'HR'},
      );
      // Six for a corner: two walls, each with its own top and bottom.
      expect(
        catalogue.frameSideLabelsFor(keyFor('SCF_win', collar: 1)),
        <String>{'WT_l', 'WT_r', 'WB_l', 'WB_r', 'HL', 'HR'},
      );
    });
  });

  group('cutting a window that is not square', () {
    const Map<String, double> margins = <String, double>{'cm': 0.5};

    WindowCutRequest window({
      SideSizes sides = const SideSizes.empty(),
      String height = '54.5',
      String width = '44.5',
    }) {
      return WindowCutRequest(
        isFabrication: true,
        appWindowCode: 'S_win',
        collarIndex: 2,
        unitMode: 'cm',
        heightValue: height,
        widthValue: width,
        lockType: 1,
        rubberType: 'F',
        sideSizes: sides,
      );
    }

    /// Every piece, as "SECTION LABEL" -> length.
    Map<String, double> lengths(WindowCutList cut) {
      final Map<String, double> out = <String, double>{};
      for (int i = 0; i < cut.pieces.length; i++) {
        final CutPiece piece = cut.pieces[i];
        out['${piece.section} ${piece.label} $i'] = piece.lengthFt;
      }
      return out;
    }

    test('the frame takes each side, the inside takes the smaller', () {
      // The shop's own example: top 44.5, bottom 46, both jambs 54.5.
      final WindowCutCalculator calculator = WindowCutCalculator(book());
      final WindowCutList cut = calculator.compute(
        window(
          sides: const SideSizes(<String, String>{
            'WT': '44.5',
            'WB': '46',
            'HL': '54.5',
            'HR': '54.5',
          }),
        ),
        margins: margins,
      );
      expect(cut.problems, isEmpty);

      // The same window cut plainly at each of the two widths, to say what
      // every piece should have come to.
      final WindowCutList atSmall =
          calculator.compute(window(width: '44.5'), margins: margins);
      final WindowCutList atWide =
          calculator.compute(window(width: '46'), margins: margins);

      final Map<String, double> mixed = lengths(cut);
      final Map<String, double> small = lengths(atSmall);
      final Map<String, double> wide = lengths(atWide);

      for (final String piece in mixed.keys) {
        final bool isSill = piece.startsWith('DC26');
        expect(
          mixed[piece],
          closeTo(isSill ? wide[piece]! : small[piece]!, 1e-12),
          reason: isSill
              ? '$piece is the sill and takes the bottom, 46'
              : '$piece takes the smaller width, 44.5',
        );
      }

      // Said plainly: the sill is the only piece that moved.
      final List<String> moved = <String>[
        for (final String piece in mixed.keys)
          if ((mixed[piece]! - small[piece]!).abs() > 1e-12) piece,
      ];
      expect(moved, hasLength(1));
      expect(moved.single, startsWith('DC26'));

      // The glass is inside the frame, so it is cut to the smaller width.
      expect(
        cut.glass.map((GlassPiece g) => '${g.heightCm}x${g.widthCm}'),
        atSmall.glass.map((GlassPiece g) => '${g.heightCm}x${g.widthCm}'),
      );
    });

    test('the jambs take their own height', () {
      final WindowCutCalculator calculator = WindowCutCalculator(book());
      final WindowCutList cut = calculator.compute(
        window(
          sides: const SideSizes(<String, String>{
            'WT': '44.5',
            'HL': '54.5',
            'HR': '56',
          }),
        ),
        margins: margins,
      );
      expect(cut.problems, isEmpty);

      final Map<String, double> short =
          lengths(calculator.compute(window(height: '54.5'), margins: margins));
      final Map<String, double> tall =
          lengths(calculator.compute(window(height: '56'), margins: margins));
      final Map<String, double> mixed = lengths(cut);

      // Both jambs are DC30C here; only the right one is the taller.
      final List<String> moved = <String>[
        for (final String piece in mixed.keys)
          if ((mixed[piece]! - short[piece]!).abs() > 1e-12) piece,
      ];
      expect(moved, hasLength(1));
      expect(moved.single, contains('HR'));
      expect(mixed[moved.single], closeTo(tall[moved.single]!, 1e-12));
    });

    test('a side left empty is the side facing it', () {
      final WindowCutCalculator calculator = WindowCutCalculator(book());
      final WindowCutList onlyTop = calculator.compute(
        window(
          sides: const SideSizes(<String, String>{'WT': '44.5', 'HL': '54.5'}),
        ),
        margins: margins,
      );
      final WindowCutList plain =
          calculator.compute(window(), margins: margins);

      expect(onlyTop.problems, isEmpty);
      expect(lengths(onlyTop), lengths(plain));
      expect(
        onlyTop.glass.map((GlassPiece g) => '${g.heightCm}x${g.widthCm}'),
        plain.glass.map((GlassPiece g) => '${g.heightCm}x${g.widthCm}'),
      );
    });

    test('a pair left empty altogether is refused, not guessed at', () {
      final WindowCutCalculator calculator = WindowCutCalculator(book());
      final WindowCutList cut = calculator.compute(
        window(sides: const SideSizes(<String, String>{'WT': '44.5'})),
        margins: margins,
      );
      expect(cut.problems, hasLength(1));
      expect(cut.problems.single, contains('Left'));
    });

    test('a corner window keeps its two walls apart', () {
      final WindowCutCalculator calculator = WindowCutCalculator(book());
      WindowCutRequest corner({SideSizes sides = const SideSizes.empty(),
          String left = '44.5', String right = '38'}) {
        return WindowCutRequest(
          isFabrication: true,
          appWindowCode: 'SCF_win',
          collarIndex: 1,
          unitMode: 'cm',
          heightValue: '54.5',
          widthValue: right,
          leftWidthValue: left,
          rightWidthValue: right,
          lockType: 1,
          rubberType: 'F',
          sideSizes: sides,
        );
      }

      final WindowCutList cut = calculator.compute(
        corner(
          sides: const SideSizes(<String, String>{
            'WT_l': '44.5',
            'WB_l': '46',
            'WT_r': '38',
            'WB_r': '38',
            'HL': '54.5',
            'HR': '54.5',
          }),
        ),
        margins: margins,
      );
      expect(cut.problems, isEmpty);

      final Map<String, double> small = lengths(calculator.compute(corner(), margins: margins));
      final Map<String, double> mixed = lengths(cut);

      // The left wall's sill is the only piece that moved: the right wall is
      // square, and the smaller of one wall says nothing about the other.
      final List<String> moved = <String>[
        for (final String piece in mixed.keys)
          if ((mixed[piece]! - small[piece]!).abs() > 1e-12) piece,
      ];
      expect(moved, hasLength(1));
      expect(moved.single, contains('WB_l'));
    });

    test('a door has three sides and is cut to them', () {
      final WindowCutCalculator calculator = WindowCutCalculator(book());
      WindowCutRequest door({SideSizes sides = const SideSizes.empty()}) {
        return WindowCutRequest(
          isFabrication: true,
          appWindowCode: 'Single_Door',
          collarIndex: 2,
          unitMode: 'cm',
          heightValue: '210',
          widthValue: '90',
          lockType: 1,
          rubberType: 'F',
          sideSizes: sides,
        );
      }

      final WindowCutList cut = calculator.compute(
        door(
          sides: const SideSizes(<String, String>{
            'WT': '90',
            'HL': '210',
            'HR': '212',
          }),
        ),
        margins: margins,
      );
      expect(cut.problems, isEmpty);

      final Map<String, double> plain = lengths(calculator.compute(door(), margins: margins));
      final Map<String, double> mixed = lengths(cut);
      final List<String> moved = <String>[
        for (final String piece in mixed.keys)
          if ((mixed[piece]! - plain[piece]!).abs() > 1e-12) piece,
      ];
      expect(moved, hasLength(1));
      expect(moved.single, contains('HR'));
    });
  });

  group('reading and keeping the sides', () {
    test('a side left empty reads as the one facing it', () {
      const SideSizes sizes = SideSizes(<String, String>{'WT': '44.5', 'HL': '54.5'});
      expect(sizes.effective('WB'), '44.5');
      expect(sizes.effective('HR'), '54.5');
      expect(sizes.raw('WB'), '', reason: 'what was typed is kept as typed');
    });

    test('the smaller of a pair is what the rest of the app is told', () {
      const SideSizes sizes = SideSizes(<String, String>{'WT': '44.5', 'WB': '46'});
      expect(sizes.smallestRaw(<String>['WT', 'WB'], unitMode: 'cm'), '44.5');
      // In inches, 44.5 is 44 inch 5 suter and 44.7 is 44 inch 7 suter.
      const SideSizes inches = SideSizes(<String, String>{'WT': '44.7', 'WB': '44.5'});
      expect(inches.smallestRaw(<String>['WT', 'WB'], unitMode: 'inches'), '44.5');
    });

    test('it reads out the way a fabricator would say it', () {
      const SideSizes sizes = SideSizes(<String, String>{
        'WT': '44.5',
        'WB': '46',
        'HL': '54.5',
        'HR': '54.5',
      });
      expect(
        sizes.describe(<String>['WT', 'WB', 'HL', 'HR']),
        '44.5/46 x 54.5',
      );
    });

    test('it survives a save and a reload, and drops a side that has gone', () {
      const SideSizes sizes = SideSizes(<String, String>{
        'WT': '44.5',
        'WB': '46',
        'HL': '54.5',
      });
      final WindowReviewItem item = WindowReviewItem(
        winNo: 1,
        windowLabel: 'Sliding Window',
        windowCode: 'S_win',
        windowIndex: 1,
        collarIndex: 2,
        unitMode: UnitMode.cm,
        heightValue: '54.5',
        widthValue: '44.5',
        sideSizes: sizes,
      );
      final WindowReviewItem read = WindowReviewItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      );
      expect(read.sideSizes, sizes);

      // A door has no bottom, so a bottom typed before the window became a
      // door cannot be cut to.
      expect(
        sizes.keepingOnly(<String>['WT', 'HL', 'HR']).toJson().keys,
        <String>['WT', 'HL'],
      );
    });

    test('a window saved before this has no sides', () {
      final WindowReviewItem read = WindowReviewItem.fromJson(<String, dynamic>{
        'winNo': 1,
        'windowCode': 'S_win',
        'heightValue': '54.5',
        'widthValue': '44.5',
      });
      expect(read.sideSizes.isEmpty, isTrue);
    });
  });

  group('the job', () {
    WindowReviewItem item(SideSizes sides) {
      return WindowReviewItem(
        winNo: 1,
        windowLabel: 'Sliding Window',
        windowCode: 'S_win',
        windowIndex: 1,
        collarIndex: 2,
        unitMode: UnitMode.cm,
        heightValue: '54.5',
        widthValue: '44.5',
        lockType: 1,
        rubberType: 'F',
        sideSizes: sides,
      );
    }

    test('the engine is told the smaller of each pair, and not the sides', () {
      final OptimizationWindowRequest sent = OptimizationWindowRequest.fromReviewItem(
        item(const SideSizes(<String, String>{
          'WT': '44.5',
          'WB': '46',
          'HL': '54.5',
          'HR': '56',
        })),
        isFabrication: true,
      );
      expect(sent.widthValue, '44.5');
      expect(sent.heightValue, '54.5');
      expect(sent.toJson().containsKey('sideSizes'), isFalse);
    });

    test('a job measured side by side is never handed back to the engine',
        () async {
      final _Api api = _Api();
      final OptimizationRepository repository = OptimizationRepository(
        apiClient: api,
        formulas: _Loader(book()),
        fabricationSettings: _Settings(),
      );

      // Only one side of the width pair, and nothing for the height: the app
      // cannot work this out, and the engine would cut it to the window.
      await expectLater(
        repository.fetchLengthOptimization(
          <WindowReviewItem>[
            item(const SideSizes(<String, String>{'WT': '44.5'})),
          ],
          context: 'fabrication',
          projectName: 'Job',
          projectLocation: 'Here',
        ),
        throwsA(isA<FormulasUnavailable>()),
      );
      expect(api.sent, isNull);
    });

    test('the lengths sent carry each side', () async {
      final _Api api = _Api();
      final OptimizationRepository repository = OptimizationRepository(
        apiClient: api,
        formulas: _Loader(book()),
        fabricationSettings: _Settings(),
      );

      await expectLater(
        repository.fetchLengthOptimization(
          <WindowReviewItem>[
            item(const SideSizes(<String, String>{
              'WT': '44.5',
              'WB': '46',
              'HL': '54.5',
              'HR': '54.5',
            })),
          ],
          context: 'fabrication',
          projectName: 'Job',
          projectLocation: 'Here',
        ),
        throwsA(isA<_Sent>()),
      );

      final OptimizationWindowRequest sent = api.sent!.windows.single;
      double lengthOf(String section, String label) {
        for (final Map<String, Object?> piece in sent.computedPieces!) {
          if (piece['section'] == section && piece['piece'] == label) {
            return piece['lengthFt']! as double;
          }
        }
        fail('$section $label was not sent');
      }

      // The sill is cut to the bottom, 46; the head to the top, 44.5 -- each
      // exactly as the same window cut plainly at that width would be.
      double plain(String section, String label, String width) {
        final WindowCutList cut = WindowCutCalculator(book()).compute(
          WindowCutRequest(
            isFabrication: true,
            appWindowCode: 'S_win',
            collarIndex: 2,
            unitMode: 'cm',
            heightValue: '54.5',
            widthValue: width,
            lockType: 1,
            rubberType: 'F',
          ),
          margins: const <String, double>{'cm': 0.5},
        );
        return cut.pieces
            .firstWhere((CutPiece p) => p.section == section && p.label == label)
            .lengthFt;
      }

      expect(lengthOf('DC26C', 'WB'), closeTo(plain('DC26C', 'WB', '46'), 1e-12));
      expect(lengthOf('DC30C', 'WT'), closeTo(plain('DC30C', 'WT', '44.5'), 1e-12));
      expect(
        lengthOf('DC26C', 'WB') - lengthOf('DC30C', 'WT'),
        closeTo((46 - 44.5) / 30.48, 1e-9),
        reason: 'the sill is the inch and a half wider edge',
      );
    });
  });
}

class _Sent implements Exception {}

class _Api implements OptimizationApiClient {
  OptimizationRequest? sent;

  @override
  Future<CuttingReport> fetchLengthOptimization(OptimizationRequest request) {
    sent = request;
    throw _Sent();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Loader implements FormulaBookLoader {
  _Loader(this.book);

  final FormulaBook book;

  @override
  Future<FormulaBook> load() async => book;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings implements FabricationSettingsRepository {
  @override
  Future<FabricationSettingsModel> fetchFabricationSettings() async =>
      const FabricationSettingsModel(cuttingMarginCm: 0.5);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
