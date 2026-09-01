import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/estimation/models/window_material.dart';
import 'package:my_app/features/estimation/widgets/window_material_picker.dart';
import 'package:my_app/shared/widgets/option_switch.dart';

/// The input screen's controls, drawn together so the set can be looked at as
/// a set. Run with --update-goldens to refresh.
Future<void> _loadLato() async {
  for (final String name in <String>['Lato-Regular', 'Lato-Bold']) {
    final File file = File('assets/fonts/$name.ttf');
    if (!file.existsSync()) continue;
    final FontLoader loader = FontLoader('Lato')
      ..addFont(
        Future<ByteData>.value(file.readAsBytesSync().buffer.asByteData()),
      );
    await loader.load();
  }
}

void main() {
  testWidgets('input controls', (WidgetTester tester) async {
    await _loadLato();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      OptionSwitchRow(
                        label: 'Unit',
                        options: <Widget>[
                          OptionSwitch(
                            label: 'Inches',
                            selected: true,
                            expand: true,
                            onTap: () {},
                          ),
                          OptionSwitch(
                            label: 'Feet',
                            selected: false,
                            expand: true,
                            onTap: () {},
                          ),
                          OptionSwitch(
                            label: 'cm',
                            selected: false,
                            expand: true,
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OptionSwitchRow(
                        label: 'Lock',
                        options: <Widget>[
                          OptionSwitch(
                            label: 'Latch',
                            selected: false,
                            expand: true,
                            onTap: () {},
                          ),
                          OptionSwitch(
                            label: 'Self',
                            selected: true,
                            expand: true,
                            onTap: () {},
                          ),
                          OptionSwitch(
                            label: 'Handal',
                            selected: false,
                            expand: true,
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      WindowMaterialPicker(
                        value: const WindowMaterial(
                          gauge: '2mm',
                          color: 'BLACK/ MULTI',
                        ),
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 16),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Height',
                          hintText: 'e.g. 60',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'e.g. bath room window',
                        ),
                      ),
                    ],
                  ),
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
      matchesGoldenFile('goldens/input_controls.png'),
    );
  });
}
