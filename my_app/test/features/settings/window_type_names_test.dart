import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/settings/models/bill_defaults.dart';

/// The windows were named by their frame's series (Hashir, Oct 2026): "Prime
/// Sliding Window" is the B/E Sliding Window, "Center Fix" the F/C Center Fix
/// and the M Center Fix. A name is a key -- hardware rates are saved under it
/// and saved jobs carry it -- so nothing priced under an old name is lost.
void main() {
  test('every new name is a window kind in the library, and no old one is', () {
    final List<String> now = WindowCatalog.allTypeNames;
    for (final MapEntry<String, List<String>> renamed in WindowCatalog.renamedTypes.entries) {
      expect(now, isNot(contains(renamed.key)), reason: renamed.key);
      for (final String name in renamed.value) {
        expect(now, contains(name), reason: '${renamed.key} -> $name');
      }
    }
    expect(now.toSet(), hasLength(now.length), reason: 'every kind priced on its own');
  });

  test('the names follow the frame series', () {
    expect(WindowCatalog.byCodeName('S_win')!.label, 'F/C Sliding Window');
    expect(WindowCatalog.byCodeName('MS_win')!.label, 'M Sliding Window');
    expect(WindowCatalog.byCodeName('PF3_win')!.label, 'F/C Center Fix');
    expect(WindowCatalog.byCodeName('MPF3_win')!.label, 'M Center Fix');
    expect(WindowCatalog.byCodeName('SCL_win')!.label, 'F/C Corner Left Fix');
    expect(WindowCatalog.byCodeName('MSCR_win')!.label, 'M Corner Right Fix');
    expect(WindowCatalog.byCodeName('SB_win')!.label, 'B/E Sliding Window');
    expect(WindowCatalog.byCodeName('PS4B_win')!.label, 'B/E Center Slide');
    expect(WindowCatalog.byCodeName('SBA_win')!.label, 'BA Sliding Window');
    expect(WindowCatalog.byCodeName('SE_win')!.label, 'EC Sliding Window');
    expect(WindowCatalog.byCodeName('MSE_win')!.label, 'ET Sliding Window');
    expect(WindowCatalog.byCodeName('MSCFE_win')!.label, 'ET Corner Center Fix');
    expect(WindowCatalog.byCodeName('SPE_win')!.label, 'EF Sliding Window');
    // The box type windows keep theirs.
    expect(WindowCatalog.byCodeName('F_win')!.label, 'Fix Window');
    expect(WindowCatalog.byCodeName('Single_Door')!.label, 'Single Door');
  });

  test('hardware rates saved under the old names move to the new ones', () {
    final BillDefaults defaults = BillDefaults.fromJson(<String, dynamic>{
      'hardware': <String, dynamic>{
        'Prime Sliding Window': '500',
        // One old name for two windows: it priced both, and still does.
        'Center Fix': '300',
        // Typed since, under the new name: kept over the old one.
        'F/C Center Slide': '450',
        'Center Slide': '400',
        'Fix Window': '200',
        'Eco Sliding Window': '',
      },
    });
    expect(defaults.hardware, <String, String>{
      'Fix Window': '200',
      'F/C Center Slide': '450',
      'B/E Sliding Window': '500',
      'F/C Center Fix': '300',
      'M Center Fix': '300',
      'M Center Slide': '400',
    });
    // Saved again, it is under today's names only.
    expect(
      (defaults.toJson()['hardware']! as Map<String, String>).keys,
      isNot(contains('Prime Sliding Window')),
    );
  });

  test('a job saved before the rename still finds its hardware rate', () {
    final BillDefaults defaults = BillDefaults.fromJson(<String, dynamic>{
      'hardware': <String, dynamic>{
        'B/E Sliding Window': '500',
        'M Center Fix': '320',
      },
    });
    // Its windows carry the old names.
    expect(defaults.rateForWindowType('Prime Sliding Window'), '500');
    expect(defaults.rateForWindowType('Center Fix'), '320');
    expect(defaults.rateForWindowType('B/E Sliding Window'), '500');
    expect(defaults.rateForWindowType('Royal Sliding Window'), isNull);
  });
}
