import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_input_preferences_store.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowInputPreferencesStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists unit mode independently per flow', () async {
      final WindowInputPreferencesStore store = WindowInputPreferencesStore();

      await store.persistUnitMode(EstimateFlow.estimation, UnitMode.inches);
      await store.persistUnitMode(EstimateFlow.fabrication, UnitMode.feet);

      expect(
        await store.restoreUnitMode(EstimateFlow.estimation),
        UnitMode.inches,
      );
      expect(
        await store.restoreUnitMode(EstimateFlow.fabrication),
        UnitMode.feet,
      );
    });

    test('persists sidebar selections per flow and window code', () async {
      final WindowInputPreferencesStore store = WindowInputPreferencesStore();

      const WindowInputSidebarPreferences openablePreferences =
          WindowInputSidebarPreferences(
            selectedCollar: 3,
            selectedSectionCode: 'D29',
            lockType: 2,
            rubberType: 'U',
            addNet: true,
          );
      const WindowInputSidebarPreferences doorPreferences =
          WindowInputSidebarPreferences(
            selectedCollar: 2,
            selectedSectionCode: 'D46',
            addBottom: true,
            addTee: false,
          );

      await store.persistSidebar(
        flow: EstimateFlow.fabrication,
        windowCode: 'O_win',
        preferencesState: openablePreferences,
      );
      await store.persistSidebar(
        flow: EstimateFlow.fabrication,
        windowCode: 'Single_Door',
        preferencesState: doorPreferences,
      );

      final WindowInputSidebarPreferences? restoredOpenable =
          await store.restoreSidebar(
            flow: EstimateFlow.fabrication,
            windowCode: 'O_win',
          );
      final WindowInputSidebarPreferences? restoredDoor =
          await store.restoreSidebar(
            flow: EstimateFlow.fabrication,
            windowCode: 'Single_Door',
          );
      final WindowInputSidebarPreferences? missing =
          await store.restoreSidebar(
            flow: EstimateFlow.estimation,
            windowCode: 'O_win',
          );

      expect(restoredOpenable, isNotNull);
      expect(restoredOpenable!.selectedCollar, 3);
      expect(restoredOpenable.selectedSectionCode, 'D29');
      expect(restoredOpenable.lockType, 2);
      expect(restoredOpenable.rubberType, 'U');
      expect(restoredOpenable.addNet, isTrue);

      expect(restoredDoor, isNotNull);
      expect(restoredDoor!.selectedCollar, 2);
      expect(restoredDoor.selectedSectionCode, 'D46');
      expect(restoredDoor.addBottom, isTrue);
      expect(restoredDoor.addTee, isFalse);

      expect(missing, isNull);
    });
  });
}
