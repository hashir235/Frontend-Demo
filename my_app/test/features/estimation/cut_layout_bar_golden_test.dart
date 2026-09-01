import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/widgets/cut_layout_bar.dart';

/// The test renderer ships no fonts, so text comes out as boxes unless a real
/// one is loaded. The app's own Lato makes the picture readable.
Future<void> _loadLato() async {
  final File file = File('assets/fonts/Lato-Bold.ttf');
  if (!file.existsSync()) return;
  final FontLoader loader = FontLoader('Lato')
    ..addFont(Future<ByteData>.value(file.readAsBytesSync().buffer.asByteData()));
  await loader.load();
}

/// Renders the bar in the states it actually appears in, so the drawing can be
/// looked at rather than only reasoned about. Run with --update-goldens to
/// refresh the image.
void main() {
  testWidgets('cut layout bar', (WidgetTester tester) async {
    await _loadLato();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Lato'),
        home: Scaffold(
          backgroundColor: const Color(0xFFF6F8FA),
          body: Center(
            child: SizedBox(
              width: 460,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('A full bar, nothing cut yet'),
                    const SizedBox(height: 8),
                    const CutLayoutBar(
                      segments: <CutLayoutSegment>[
                        CutLayoutSegment(label: '3/WT', lengthFt: 5),
                        CutLayoutSegment(label: '1/H', lengthFt: 5),
                        CutLayoutSegment(label: '1/WB', lengthFt: 4),
                        CutLayoutSegment(label: '2/H', lengthFt: 2.4),
                      ],
                      wastageFt: 1.6,
                      isOffcut: false,
                      totalLabel: '18 ft',
                    ),
                    const SizedBox(height: 26),
                    const Text('Two pieces ticked off at the saw'),
                    const SizedBox(height: 8),
                    const CutLayoutBar(
                      segments: <CutLayoutSegment>[
                        CutLayoutSegment(
                          label: '3/WT',
                          lengthFt: 5,
                          isCut: true,
                        ),
                        CutLayoutSegment(
                          label: '1/H',
                          lengthFt: 5,
                          isCut: true,
                        ),
                        CutLayoutSegment(label: '1/WB', lengthFt: 4),
                        CutLayoutSegment(label: '2/H', lengthFt: 2.4),
                      ],
                      wastageFt: 1.6,
                      isOffcut: false,
                      totalLabel: '18 ft',
                    ),
                    const SizedBox(height: 26),
                    const Text('A leftover bar, with a narrow piece'),
                    const SizedBox(height: 8),
                    const CutLayoutBar(
                      segments: <CutLayoutSegment>[
                        CutLayoutSegment(label: '4/WT', lengthFt: 7),
                        CutLayoutSegment(label: '4/S', lengthFt: 0.6),
                        CutLayoutSegment(label: '5/H', lengthFt: 3),
                      ],
                      wastageFt: 2.4,
                      isOffcut: true,
                      totalLabel: '13 ft',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/cut_layout_bar.png'),
    );
  });
}
