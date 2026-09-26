import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/fabrication/data/glass_sheet_optimization_api_client.dart';
import 'package:my_app/features/fabrication/models/glass_report.dart';
import 'package:my_app/features/fabrication/presentation/glass_sheet_optimization_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The glass sheets screen shows the used glass twice: by the tape (Math
/// Standard) and as the market sells it (Market Standard), for the whole job,
/// for each sheet, and for each piece.
void main() {
  // Two pieces on one 84 x 144 sheet: 14 x 20 laid on its side, and 30 x 43.
  final Map<String, dynamic> optimized = <String, dynamic>{
    'ok': true,
    'errors': <String>[],
    'projectName': 'Market Test',
    'projectLocation': 'Lahore',
    'sheet': <String, dynamic>{
      'width': 84,
      'height': 144,
      'widthDisplay': '84 in',
      'heightDisplay': '144 in',
      'allowRotation': true,
    },
    'summary': <String, dynamic>{
      'totalSheets': 1,
      'totalPieces': 2,
      'placedPieces': 2,
      'rejectedPieces': 0,
      'usedArea': 1570,
      'wasteArea': 10526,
      'totalArea': 12096,
      'wastagePercentage': 87.02,
    },
    'sourceRows': <Map<String, dynamic>>[],
    'rejectedPieces': <Map<String, dynamic>>[],
    'sheets': <Map<String, dynamic>>[
      <String, dynamic>{
        'sheetNo': 1,
        'width': 84,
        'height': 144,
        'widthDisplay': '84 in',
        'heightDisplay': '144 in',
        'usedArea': 1570,
        'wasteArea': 10526,
        'wastagePercentage': 87.02,
        'glassColor': 'Clear Glass',
        'placements': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'a',
            'label': 'Door',
            'pieceNo': 1,
            'x': 0,
            'y': 0,
            'width': 30,
            'height': 43,
            'glassSizeDisplay': "30'' 0''' x 43'' 0'''",
            'rotated': false,
          },
          <String, dynamic>{
            'id': 'b',
            'label': 'Sliding Window',
            'pieceNo': 2,
            'x': 30,
            'y': 0,
            'width': 20,
            'height': 14,
            'glassSizeDisplay': "14'' 0''' x 20'' 0'''",
            'rotated': true,
          },
        ],
        'wasteRects': <Map<String, dynamic>>[],
      },
    ],
  };

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: GlassSheetOptimizationScreen(
          glassReport: const GlassReport(
            ok: true,
            errors: <String>[],
            projectName: 'Market Test',
            projectLocation: 'Lahore',
            rows: <GlassReportRow>[],
          ),
          apiClient: GlassSheetOptimizationApiClient(
            baseUrl: 'http://test',
            httpClient: MockClient(
              (http.Request request) async =>
                  http.Response(jsonEncode(optimized), 200),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.auto_awesome_mosaic_rounded));
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Finder text(String value) => find.textContaining(value);

  // The list builds only what is near the screen, so scroll to each line.
  Future<void> seek(WidgetTester tester, String value) async {
    await tester.scrollUntilVisible(
      text(value),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(text(value), findsWidgets);
  }

  testWidgets('the job total is shown by the tape and by the market', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await seek(tester, 'Used · Math Standard');
    await seek(tester, 'Used · Market Standard');
    // 30 x 48 = 1440, and 15 x 21 = 315, before the sheet shows it again.
    await seek(tester, '1755 sq in');
  });

  testWidgets('each piece shows its market sides and area', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await seek(tester, 'Math: 1290 sq in');
    await seek(tester, "Market: 30'' x 48''");
    await seek(tester, 'Math: 280 sq in');
    // Laid on its side, the piece is still 14 by 20, so 15 by 21.
    await seek(tester, "Market: 15'' x 21''");
  });
}
