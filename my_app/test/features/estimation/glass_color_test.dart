import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/glass_color.dart';
import 'package:my_app/features/estimation/models/optimization_request.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/fabrication/models/glass_report.dart';
import 'package:my_app/features/fabrication/models/glass_sheet_optimization.dart';
import 'package:my_app/features/settings/models/bill_defaults.dart';

/// Glass belongs to the window, not to the job.
///
/// One job is rarely one glass -- the bathroom goes in obscured while the room
/// beside it is clear -- and those do not cost the same per foot. Whatever is
/// picked here decides which rate that window's glazing is charged at, so a
/// glass that goes missing between the input screen and the bill is money.
void main() {
  WindowReviewItem window(int no, {String? glass}) {
    return WindowReviewItem(
      winNo: no,
      windowLabel: 'Sliding Window',
      windowCode: 'S_win',
      windowIndex: 1,
      collarIndex: 1,
      unitMode: UnitMode.inches,
      heightValue: '60.0',
      widthValue: '48.0',
      glassColor: glass ?? GlassColors.initial,
    );
  }

  group('the list', () {
    test('is the one the rates screen prices', () {
      // A second list would drift, and the day it did a job would be glazed in
      // something the bill had no price for.
      expect(GlassColors.all, same(GlassTypes.all));
      expect(GlassColors.all, contains('Green Mercury'));
      expect(GlassColors.all, hasLength(10));
    });

    test('every glass has a rate slot it can reach', () {
      // The bill looks a rate up by matching the name. A colour the picker can
      // produce but the rates screen cannot match would be unpriceable.
      for (final String color in GlassColors.all) {
        expect(GlassTypes.match(color), color, reason: color);
      }
    });

    test('mercury and plain of the same colour do not look alike', () {
      // The swatch is what a fitter who cannot read English picks by.
      expect(
        GlassColors.swatchFor('Green Mercury'),
        isNot(GlassColors.swatchFor('Green Simple')),
      );
      expect(GlassColors.isMercury('Green Mercury'), isTrue);
      expect(GlassColors.isMercury('Green Simple'), isFalse);
    });

    test('an unknown or missing glass reads as clear', () {
      // Jobs quoted before glass was per-window were all billed at one glass,
      // and clear is what those were quoted at.
      expect(GlassColors.normalize(null), 'Clear Glass');
      expect(GlassColors.normalize(''), 'Clear Glass');
      expect(GlassColors.normalize('Bronze Something'), 'Clear Glass');
      // Case and spacing are the user's, not ours.
      expect(GlassColors.normalize('green mercury'), 'Green Mercury');
    });
  });

  group('it stays with the window', () {
    test('through a save and a reload', () {
      final WindowReviewItem saved = window(1, glass: 'Blue Mercury');
      final WindowReviewItem read = WindowReviewItem.fromJson(saved.toJson());
      expect(read.glassColor, 'Blue Mercury');
    });

    test('a window saved before this existed reads as clear, not blank', () {
      final Map<String, dynamic> old = window(1).toJson()..remove('glassColor');
      expect(WindowReviewItem.fromJson(old).glassColor, 'Clear Glass');
    });

    test('and reaches the engine on the wire', () {
      final OptimizationWindowRequest request =
          OptimizationWindowRequest.fromReviewItem(
            window(1, glass: 'Gray Simple'),
            isFabrication: false,
          );
      expect(request.glassColor, 'Gray Simple');
      expect(request.toJson()['glassColor'], 'Gray Simple');
    });
  });

  group('on the fabrication side', () {
    GlassReportRow row({String glass = ''}) {
      return GlassReportRow.fromInputs(
        width: const GlassDimension(inches: 20, sutter: 0),
        height: const GlassDimension(inches: 40, sutter: 0),
        windowName: 'Sliding',
        windowNo: 1,
        rubberType: 'F',
        quantity: 2,
        glassColor: glass,
      );
    }

    test('the glass rides on the cutting row', () {
      expect(row(glass: 'Green Mercury').glassColor, 'Green Mercury');
    });

    test('it survives the trip to the server and back', () {
      // The optimizer groups on this. A row that loses its glass on the wire
      // is a row that gets packed onto somebody else's sheet.
      final GlassReportRow sent = row(glass: 'Blue Simple');
      final GlassReportRow back = GlassReportRow.fromJson(sent.toJson());
      expect(back.glassColor, 'Blue Simple');
    });

    test('a row from an older server has no glass, not a wrong one', () {
      final Map<String, dynamic> old = row(glass: 'Blue Simple').toJson()
        ..remove('glassColor');
      expect(GlassReportRow.fromJson(old).glassColor, '');
    });

    test('editing a row keeps its glass', () {
      final GlassReportRow edited = row(glass: 'Ocean Blue').copyWith(
        quantity: 5,
      );
      expect(edited.glassColor, 'Ocean Blue');
      expect(edited.quantity, 5);
    });

    test('a sheet says which glass it is', () {
      final GlassSheetLayout sheet = GlassSheetLayout.fromJson(
        <String, dynamic>{
          'sheetNo': 2,
          'width': 84,
          'height': 144,
          'glassColor': 'Gray Mercury',
          'placements': <dynamic>[],
          'wasteRects': <dynamic>[],
        },
      );
      expect(sheet.glassColor, 'Gray Mercury');
    });
  });

  group('the next window', () {
    EstimateSessionStore session() => EstimateSessionStore(
      projectName: 'Test Project',
      projectLocation: 'Test Location',
    );

    test('starts on clear when the job is empty', () {
      expect(session().glassColorForNextWindow, 'Clear Glass');
    });

    test('inherits whatever the last one was glazed in', () {
      // Most jobs are mostly one glass. A shop should pick it once.
      final EstimateSessionStore store = session();
      store.addItem(
        winNo: 1,
        windowLabel: 'Sliding Window',
        windowCode: 'S_win',
        windowIndex: 1,
        collarIndex: 1,
        unitMode: UnitMode.inches,
        heightValue: '60.0',
        widthValue: '48.0',
        glassColor: 'Ocean Blue',
      );
      expect(store.glassColorForNextWindow, 'Ocean Blue');

      final WindowReviewItem next = store.addItem(
        winNo: 2,
        windowLabel: 'Sliding Window',
        windowCode: 'S_win',
        windowIndex: 1,
        collarIndex: 1,
        unitMode: UnitMode.inches,
        heightValue: '60.0',
        widthValue: '48.0',
      );
      expect(
        next.glassColor,
        'Ocean Blue',
        reason: 'it carries over until somebody moves it',
      );
    });

    test('one window changing it does not move the others', () {
      final EstimateSessionStore store = session();
      store.replaceItems(<WindowReviewItem>[
        window(1, glass: 'Clear Glass'),
        window(2, glass: 'Brown Mercury'),
        window(3, glass: 'Clear Glass'),
      ]);
      expect(
        store.items.map((WindowReviewItem i) => i.glassColor),
        <String>['Clear Glass', 'Brown Mercury', 'Clear Glass'],
      );
    });
  });
}
