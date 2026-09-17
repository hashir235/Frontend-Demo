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
import 'package:my_app/features/formulas/model/piece_size.dart';
import 'package:my_app/features/settings/data/fabrication_settings_repository.dart';
import 'package:my_app/features/settings/models/fabrication_settings.dart';

/// One piece of one window, cut to a size of its own.
///
/// The formula screen showed each piece worked out on the window's size, in a
/// box that could be typed over -- and then threw the typed size away, so the
/// cutting list went on cutting to the window. These hold the whole way from
/// that box to the lengths the saw is sent, against the real catalogue.
void main() {
  late FormulaCatalogue catalogue;

  setUpAll(() {
    catalogue = FormulaCatalogue.fromJson(
      jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  FormulaWindowKey sliding() {
    return FormulaWindowKey.of(
      context: 'fabrication',
      appWindowCode: 'S_win',
      dimensions: catalogue.dimensionsFor('fabrication/S_win'),
      collarIndex: 2,
      lockType: 1,
      rubberType: 'F',
    )!;
  }

  FormulaBook book() => FormulaBook(catalogue, FormulaOverrides.empty());

  WindowCutRequest window({
    String height = '220.6',
    List<PieceSize> sizes = const <PieceSize>[],
  }) {
    return WindowCutRequest(
      isFabrication: true,
      appWindowCode: 'S_win',
      collarIndex: 2,
      unitMode: 'cm',
      heightValue: height,
      widthValue: '182.5',
      lockType: 1,
      rubberType: 'F',
      pieceSizes: sizes,
    );
  }

  const Map<String, double> margins = <String, double>{'cm': 0.5};

  /// The first piece in the window driven by the height, and the size of its
  /// own it is given.
  ({EffectiveFormula piece, PieceSize size}) ownHeight(double size) {
    final EffectiveFormula piece = book()
        .sectionsFor(sliding())!
        .expand((EffectiveSection s) => s.pieces)
        .firstWhere((EffectiveFormula p) => p.slot.dimension == 'h');
    return (
      piece: piece,
      size: PieceSize(
        ref: piece.ref,
        label: piece.slot.label,
        dimension: 'h',
        base: 220.6,
        size: size,
      ),
    );
  }

  group('cutting', () {
    test('the piece is cut to its own size, and no other piece moves', () {
      final WindowCutCalculator calculator = WindowCutCalculator(book());
      final ({EffectiveFormula piece, PieceSize size}) own = ownHeight(200);

      final WindowCutList plain = calculator.compute(window(), margins: margins);
      final WindowCutList sized = calculator.compute(
        window(sizes: <PieceSize>[own.size]),
        margins: margins,
      );
      expect(plain.problems, isEmpty);
      expect(sized.problems, isEmpty);
      expect(sized.pieces.length, plain.pieces.length);

      // Worked out exactly as the formula would for a window 200cm high.
      final double expected = own.piece.slot
          .lengthFor(<String, double>{
            'h': 200,
            'w': 182.5,
            'wl': 182.5,
            'wr': 182.5,
            'ar': 0,
            'feet': 30.48,
            'cm': 0.5,
          })
          .value!;

      int differing = 0;
      for (int i = 0; i < plain.pieces.length; i++) {
        if (plain.pieces[i].lengthFt != sized.pieces[i].lengthFt) {
          differing++;
          expect(sized.pieces[i].label, own.piece.slot.label);
          expect(sized.pieces[i].lengthFt, closeTo(expected, 1e-12));
        }
      }
      expect(differing, 1, reason: 'one piece has a size of its own, one moves');

      // The glass is driven by the window, not by that piece.
      expect(
        sized.glass.map((GlassPiece g) => '${g.heightCm}x${g.widthCm}'),
        plain.glass.map((GlassPiece g) => '${g.heightCm}x${g.widthCm}'),
      );
    });

    test('a pane of glass can be given its own size too', () {
      final WindowCutCalculator calculator = WindowCutCalculator(book());
      final EffectiveSection pane = book().glassFor(sliding()).first;
      final EffectiveFormula height = pane.pieces[0];

      final WindowCutList sized = calculator.compute(
        window(sizes: <PieceSize>[
          PieceSize(
            ref: height.ref,
            label: height.slot.label,
            dimension: height.slot.dimension,
            base: 220.6,
            size: 210,
          ),
        ]),
        margins: margins,
      );
      final WindowCutList plain = calculator.compute(window(), margins: margins);

      expect(sized.problems, isEmpty);
      // The engine's F-rubber pane takes 14.2 off the height.
      expect(sized.glass.first.heightCm, closeTo(210 - 14.2, 1e-9));
      expect(plain.glass.first.heightCm, closeTo(220.6 - 14.2, 1e-9));
      expect(sized.glass.first.widthCm, plain.glass.first.widthCm);
      // Only the pane it was set on.
      expect(sized.glass.last.heightCm, plain.glass.last.heightCm);
    });

    test('a size set before the window was re-measured stops the job', () {
      // Cutting to 200 when the window is now 230 would be a size chosen for
      // a different window; quietly cutting to 230 would ignore what was asked.
      final WindowCutCalculator calculator = WindowCutCalculator(book());
      final ({EffectiveFormula piece, PieceSize size}) own = ownHeight(200);

      final WindowCutList cut = calculator.compute(
        window(height: '230', sizes: <PieceSize>[own.size]),
        margins: margins,
      );
      expect(cut.problems, hasLength(1));
      expect(cut.problems.single, contains(own.piece.slot.label));
      expect(cut.problems.single, contains('set it again'));
    });

    test('a size for another collar type is not this window\'s', () {
      final WindowCutCalculator calculator = WindowCutCalculator(book());
      final ({EffectiveFormula piece, PieceSize size}) own = ownHeight(200);
      final PieceSize elsewhere = PieceSize(
        ref: FormulaPieceRef(
          windowKey: own.size.ref.windowKey,
          configKey: 'collarType=13|lockType=1|rubberType=F',
          section: own.size.ref.section,
          index: own.size.ref.index,
        ),
        label: own.size.label,
        dimension: 'h',
        base: 220.6,
        size: 200,
      );

      final WindowCutList plain = calculator.compute(window(), margins: margins);
      final WindowCutList cut = calculator.compute(
        window(sizes: <PieceSize>[elsewhere]),
        margins: margins,
      );
      expect(
        cut.pieces.map((CutPiece p) => p.lengthFt),
        plain.pieces.map((CutPiece p) => p.lengthFt),
      );
    });
  });

  group('keeping it', () {
    test('it goes with the window through a save and a reload', () {
      final PieceSize size = ownHeight(200).size;
      final WindowReviewItem item = WindowReviewItem(
        winNo: 3,
        windowLabel: 'Sliding Window',
        windowCode: 'S_win',
        windowIndex: 1,
        collarIndex: 2,
        unitMode: UnitMode.cm,
        heightValue: '220.6',
        widthValue: '182.5',
        lockType: 1,
        rubberType: 'F',
        pieceSizes: <PieceSize>[size],
      );

      final WindowReviewItem read =
          WindowReviewItem.fromJson(jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>);
      expect(read.pieceSizes, <PieceSize>[size]);
    });

    test('a window saved before this has none', () {
      final WindowReviewItem read = WindowReviewItem.fromJson(<String, dynamic>{
        'winNo': 1,
        'windowCode': 'S_win',
        'heightValue': '60',
        'widthValue': '48',
      });
      expect(read.pieceSizes, isEmpty);
    });

    test('anything that is not a size that can be cut to is dropped', () {
      final Map<String, Object?> good = ownHeight(200).size.toJson();
      final List<PieceSize> read = PieceSize.listFromJson(<Object?>[
        good,
        <String, Object?>{...good, 'size': 0},
        <String, Object?>{...good, 'base': -5},
        <String, Object?>{...good, 'index': 'two'},
        'not a size',
      ]);
      expect(read, hasLength(1));
    });

    test('it stands only for the measurement it was set against', () {
      final PieceSize size = ownHeight(200).size;
      expect(size.standsFor(220.6), isTrue);
      expect(size.standsFor(220.6000001), isTrue, reason: 'conversion noise');
      expect(size.standsFor(220.7), isFalse);
    });
  });

  group('the job', () {
    WindowReviewItem item(List<PieceSize> sizes, {String height = '220.6'}) {
      return WindowReviewItem(
        winNo: 1,
        windowLabel: 'Sliding Window',
        windowCode: 'S_win',
        windowIndex: 1,
        collarIndex: 2,
        unitMode: UnitMode.cm,
        heightValue: height,
        widthValue: '182.5',
        lockType: 1,
        rubberType: 'F',
        pieceSizes: sizes,
      );
    }

    test('the size is in the lengths sent, and is not itself sent', () async {
      final _Api api = _Api();
      final OptimizationRepository repository = OptimizationRepository(
        apiClient: api,
        formulas: _Loader(book()),
        fabricationSettings: _Settings(),
      );
      final ({EffectiveFormula piece, PieceSize size}) own = ownHeight(200);

      await expectLater(
        repository.fetchLengthOptimization(
          <WindowReviewItem>[item(<PieceSize>[own.size])],
          context: 'fabrication',
          projectName: 'Job',
          projectLocation: 'Here',
        ),
        throwsA(isA<_Sent>()),
      );

      final OptimizationWindowRequest sent = api.sent!.windows.single;
      final List<double> lengths = <double>[
        for (final Map<String, Object?> piece in sent.computedPieces!)
          if (piece['piece'] == own.piece.slot.label &&
              piece['section'] == own.piece.slot.section)
            piece['lengthFt']! as double,
      ];
      final double at200 = own.piece.slot.lengthFor(<String, double>{
        'h': 200,
        'w': 182.5,
        'wl': 182.5,
        'wr': 182.5,
        'ar': 0,
        'feet': 30.48,
        'cm': 0.5,
      }).value!;
      expect(lengths.first, closeTo(at200, 1e-12),
          reason: 'cut to 200cm, not the window\'s 220.6');
      expect(sent.toJson().containsKey('pieceSizes'), isFalse);
    });

    test('a job with a size that no longer stands is never handed to the '
        'engine to work out instead', () async {
      final _Api api = _Api();
      final OptimizationRepository repository = OptimizationRepository(
        apiClient: api,
        formulas: _Loader(book()),
        fabricationSettings: _Settings(),
      );

      await expectLater(
        repository.fetchLengthOptimization(
          <WindowReviewItem>[item(<PieceSize>[ownHeight(200).size], height: '230')],
          context: 'fabrication',
          projectName: 'Job',
          projectLocation: 'Here',
        ),
        throwsA(isA<FormulasUnavailable>()),
      );
      expect(api.sent, isNull, reason: 'the engine would cut to the window');
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
