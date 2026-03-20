import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';

void main() {
  group('EstimateSessionStore.restoreOutputs', () {
    test('hydrates material selection, overrides, and bill draft', () {
      final EstimateSessionStore session = EstimateSessionStore(
        projectName: 'Quick AL',
        projectLocation: 'Karachi',
      );

      session.restoreOutputs(<String, dynamic>{
        'costTable': <String, dynamic>{
          'request': <String, dynamic>{
            'gauge': '1.4',
            'color': 'Black',
            'overrides': <Map<String, dynamic>>[
              <String, dynamic>{'section': 'Frame', 'rate': 12.5},
              <String, dynamic>{'section': 'Sash', 'rate': 8},
            ],
          },
        },
        'billResult': <String, dynamic>{
          'glassColor': 'Blue',
          'rates': <String, dynamic>{
            'glassPerSqFt': 350,
            'laborPerSqFt': 55.5,
            'hardwarePerWindow': 120,
            'aluminiumDiscountPercent': 7,
          },
          'totals': <String, dynamic>{
            'extraCharges': 500,
            'advancePaid': 1000,
          },
          'customer': <String, dynamic>{
            'name': 'Ali',
            'phone': '03001234567',
            'address': 'North Nazimabad',
          },
        },
      });

      expect(session.materialSelection, isNotNull);
      expect(session.materialSelection!.gaugeValue, '1.4');
      expect(session.materialSelection!.colorValue, 'Black');

      expect(session.rateOverrides, hasLength(2));
      expect(session.rateOverrides.first.section, 'Frame');
      expect(session.rateOverrides.first.rate, 12.5);
      expect(session.rateOverrides.last.section, 'Sash');
      expect(session.rateOverrides.last.rate, 8);

      expect(session.billDraft, isNotNull);
      expect(session.billDraft!.glassRatePerSqFt, '350');
      expect(session.billDraft!.laborRatePerSqFt, '55.5');
      expect(session.billDraft!.hardwareRatePerWindow, '120');
      expect(session.billDraft!.aluminiumDiscountPercent, '7');
      expect(session.billDraft!.extraCharges, '500');
      expect(session.billDraft!.advancePaid, '1000');
      expect(session.billDraft!.glassColor, 'Blue');
      expect(session.billDraft!.customerName, 'Ali');
      expect(session.billDraft!.customerPhone, '03001234567');
      expect(session.billDraft!.customerAddress, 'North Nazimabad');
    });

    test('clears restored flow state when outputs are empty', () {
      final EstimateSessionStore session = EstimateSessionStore(
        projectName: 'Quick AL',
        projectLocation: 'Karachi',
      );

      session.restoreOutputs(<String, dynamic>{
        'costTable': <String, dynamic>{
          'request': <String, dynamic>{
            'gauge': '1.2',
            'color': 'Brown',
            'overrides': <Map<String, dynamic>>[
              <String, dynamic>{'section': 'Frame', 'rate': 9.5},
            ],
          },
        },
        'billResult': <String, dynamic>{
          'glassColor': 'Clear',
          'rates': <String, dynamic>{'glassPerSqFt': 120},
        },
      });

      session.restoreOutputs(null);

      expect(session.materialSelection, isNull);
      expect(session.rateOverrides, isEmpty);
      expect(session.billDraft, isNull);
    });
  });
}
