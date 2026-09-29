import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/window_material.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/state/last_window_material.dart';
import 'package:my_app/features/settings/state/app_settings.dart';
import 'package:my_app/features/settings/state/numbering_mode.dart';
import 'package:my_app/features/settings/state/size_input_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A button stays where the shop left it -- across closing and opening the
/// app -- until the shop moves it again.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSettings.instance.resetForTest();
    LastWindowMaterial.instance.resetForTest();
  });

  /// Lets the background writes to the phone finish.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  /// What the app reads when it opens again.
  Future<void> reopen() async {
    AppSettings.instance.resetForTest();
    await AppSettings.instance.load();
  }

  group('settings', () {
    test('numbering and size typing come back as they were left', () async {
      AppSettings.instance.setNumberingMode(NumberingMode.manual);
      AppSettings.instance.setSizeInputMode(SizeInputMode.wheel);
      await settle();
      await reopen();
      expect(AppSettings.instance.numberingMode, NumberingMode.manual);
      expect(AppSettings.instance.sizeInputMode, SizeInputMode.wheel);
    });

    test('a phone that never chose opens on the usual ones', () async {
      await reopen();
      expect(AppSettings.instance.numberingMode, NumberingMode.auto);
      expect(AppSettings.instance.sizeInputMode, SizeInputMode.mergedKeypad);
      expect(AppSettings.instance.extraLengthUnit, isNull);
      expect(AppSettings.instance.customGlassSheet, isFalse);
      expect(AppSettings.instance.glassSheetWidthFt, '7');
      expect(AppSettings.instance.glassSheetHeightFt, '12');
      expect(AppSettings.instance.allowGlassRotation, isTrue);
    });

    test('glass sheet: its own size and rotation come back', () async {
      AppSettings.instance.setCustomGlassSheet(true);
      AppSettings.instance.setGlassSheetSize(widthFt: '6', heightFt: '10.5');
      AppSettings.instance.setAllowGlassRotation(false);
      AppSettings.instance.setExtraLengthUnit('cm');
      await settle();
      await reopen();
      expect(AppSettings.instance.customGlassSheet, isTrue);
      expect(AppSettings.instance.glassSheetWidthFt, '6');
      expect(AppSettings.instance.glassSheetHeightFt, '10.5');
      expect(AppSettings.instance.allowGlassRotation, isFalse);
      expect(AppSettings.instance.extraLengthUnit, 'cm');
    });

    test('something unreadable on the phone falls back, never breaks', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'quick_al.numbering_mode': 'sideways',
        'quick_al.size_input_mode': '',
      });
      await reopen();
      expect(AppSettings.instance.numberingMode, NumberingMode.auto);
      expect(AppSettings.instance.sizeInputMode, SizeInputMode.mergedKeypad);
    });
  });

  group('gauge and colour', () {
    EstimateSessionStore job() =>
        EstimateSessionStore(projectName: 'Job', projectLocation: 'Lahore');

    const WindowMaterial twoMmBlack = WindowMaterial(
      gauge: WindowGauges.g2,
      color: AluminiumColors.black,
    );

    test('the first window of a new job opens on the stock picked last', () async {
      expect(
        job().materialForNextWindow,
        WindowMaterial.initial,
        reason: 'nothing picked yet',
      );
      await LastWindowMaterial.instance.remember(twoMmBlack);
      expect(job().materialForNextWindow, twoMmBlack);

      // And after the app is closed and opened again.
      LastWindowMaterial.instance.resetForTest();
      await LastWindowMaterial.instance.load();
      expect(job().materialForNextWindow, twoMmBlack);
    });

    test('inside a job, the next window still follows the last one entered', () async {
      await LastWindowMaterial.instance.remember(twoMmBlack);
      final EstimateSessionStore session = job();
      session.addItem(
        winNo: 1,
        windowLabel: 'Sliding Window',
        windowCode: 'S_win',
        windowIndex: 1,
        collarIndex: 1,
        unitMode: UnitMode.inches,
        heightValue: '60.0',
        widthValue: '48.0',
        material: const WindowMaterial(
          gauge: WindowGauges.g16,
          color: AluminiumColors.dull,
        ),
      );
      expect(
        session.materialForNextWindow,
        const WindowMaterial(gauge: WindowGauges.g16, color: AluminiumColors.dull),
      );
    });

    test('a gauge or colour no longer on the rate list opens on the default', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'quick_al.last_window_gauge': '3mm',
        'quick_al.last_window_color': 'GOLD',
      });
      await LastWindowMaterial.instance.load();
      expect(LastWindowMaterial.instance.value, WindowMaterial.initial);
    });
  });
}
