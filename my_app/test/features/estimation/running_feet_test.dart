import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/area_method.dart';
import 'package:my_app/features/estimation/models/bill_snapshot.dart';
import 'package:my_app/features/estimation/models/cost_table.dart';
import 'package:my_app/features/settings/models/bill_defaults.dart';

/// Running feet: how Karachi bills a window. The billing itself is the
/// server's (services/running_feet.js, checked against the engine there);
/// here, the switch and the unit every bill figure is printed in.
void main() {
  group('the switch', () {
    test('on by default in Karachi, off elsewhere', () {
      expect(BillDefaults.runningFeetFor(null, 'Karachi'), isTrue);
      expect(BillDefaults.runningFeetFor(null, ' karachi '), isTrue);
      expect(BillDefaults.runningFeetFor(null, 'Lahore'), isFalse);
      expect(BillDefaults.runningFeetFor(null, ''), isFalse);
    });

    test("the workshop's own choice wins over its city", () {
      expect(BillDefaults.runningFeetFor(false, 'Karachi'), isFalse);
      expect(BillDefaults.runningFeetFor(true, 'Gujrat'), isTrue);
    });

    test('read from the server: chosen, or not yet', () {
      expect(BillDefaults.fromJson(<String, dynamic>{'runningFeet': true}).runningFeet, isTrue);
      expect(BillDefaults.fromJson(<String, dynamic>{'runningFeet': false}).runningFeet, isFalse);
      expect(BillDefaults.fromJson(<String, dynamic>{'runningFeet': null}).runningFeet, isNull);
      expect(BillDefaults.fromJson(const <String, dynamic>{}).runningFeet, isNull,
          reason: 'an older server says nothing');
    });

    test('saving the rates never sends it (it is saved on its own)', () {
      const BillDefaults defaults = BillDefaults(labourRate: '120', runningFeet: true);
      expect(defaults.toJson().containsKey('runningFeet'), isFalse);
      expect(defaults.copyWith(labourRate: '130').runningFeet, isTrue);
    });
  });

  group('the unit on a bill', () {
    test('Rn.ft for a bill made in running feet, sq.ft otherwise', () {
      expect(areaUnitFor('running'), 'Rn.ft');
      expect(areaUnitFor(''), 'sq.ft');
      expect(areaUnitFor('square'), 'sq.ft');
    });

    test('the bill says which it was made in', () {
      final BillSnapshot running = BillSnapshot.fromJson(<String, dynamic>{
        'ok': true,
        'areaMethod': 'running',
      });
      expect(running.areaUnit, 'Rn.ft');
      final BillSnapshot before = BillSnapshot.fromJson(<String, dynamic>{'ok': true});
      expect(before.areaUnit, 'sq.ft', reason: 'every bill made before is square feet');
    });

    test('the glass footage beside the rate boxes says it too', () {
      final CostTable running = CostTable.fromJson(<String, dynamic>{
        'ok': true,
        'areaMethod': 'running',
        'glassAreas': <Map<String, dynamic>>[
          <String, dynamic>{'color': 'Clear Glass', 'areaSqFt': 14, 'windows': 1},
        ],
      });
      expect(running.areaUnit, 'Rn.ft');
      expect(running.glassAreas.single.areaSqFt, 14);
      expect(CostTable.fromJson(<String, dynamic>{'ok': true}).areaUnit, 'sq.ft');
    });
  });
}
