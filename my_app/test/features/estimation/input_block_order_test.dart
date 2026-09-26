import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/presentation/input/input_block_order.dart';

/// The order a shop moves the input screen's parts into: kept whole, shared
/// by every window, and forgiving of parts a window does not have.
void main() {
  const List<String> d = InputBlockOrder.defaults;

  group('resolve', () {
    test('nothing saved is the screen as it came', () {
      expect(InputBlockOrder.resolve(null), d);
      expect(InputBlockOrder.resolve(const <String>[]), d);
    });

    test('unknown and repeated ids are dropped', () {
      final List<String> saved = <String>['glassColor', 'bogus', ...d, 'glassColor'];
      final List<String> order = InputBlockOrder.resolve(saved);
      expect(order.first, 'glassColor');
      expect(order.length, d.length);
      expect(order.toSet(), d.toSet());
    });

    test('a part the saved order has never heard of goes back after the '
        'part it follows by default', () {
      // Saved by a version without the per-side switch.
      final List<String> saved = <String>[
        for (final String id in d)
          if (id != InputBlockOrder.perSide) id,
      ];
      final List<String> order = InputBlockOrder.resolve(saved);
      expect(
        order.indexOf(InputBlockOrder.perSide),
        order.indexOf(InputBlockOrder.rubber) + 1,
      );
    });

    test('a missing first part goes back to the top', () {
      final List<String> order = InputBlockOrder.resolve(d.sublist(1));
      expect(order.first, InputBlockOrder.collar);
    });
  });

  group('arrange', () {
    test("only this window's parts, in the saved order", () {
      final List<String> saved = <String>[
        InputBlockOrder.description,
        ...d.where((String id) => id != InputBlockOrder.description),
      ];
      final List<String> shown = InputBlockOrder.arrange(saved, <String>{
        InputBlockOrder.sizes,
        InputBlockOrder.collar,
        InputBlockOrder.description,
      });
      expect(shown, <String>[
        InputBlockOrder.description,
        InputBlockOrder.collar,
        InputBlockOrder.sizes,
      ]);
    });
  });

  group('merge', () {
    test('parts this window lacks stay with the part they followed', () {
      // An estimate: no lock, no rubber. Glass is dragged to the top.
      final Set<String> estimate = d
          .where(
            (String id) =>
                id != InputBlockOrder.lock && id != InputBlockOrder.rubber,
          )
          .toSet();
      final List<String> shown = InputBlockOrder.arrange(d, estimate);
      final List<String> moved = <String>[
        InputBlockOrder.glassColor,
        ...shown.where((String id) => id != InputBlockOrder.glassColor),
      ];

      final List<String> merged = InputBlockOrder.merge(d, moved);

      expect(merged.first, InputBlockOrder.glassColor);
      expect(merged.length, d.length);
      // Lock and rubber still sit right after the unit row, where a
      // fabrication window will look for them.
      expect(
        merged.indexOf(InputBlockOrder.lock),
        merged.indexOf(InputBlockOrder.unit) + 1,
      );
      expect(
        merged.indexOf(InputBlockOrder.rubber),
        merged.indexOf(InputBlockOrder.lock) + 1,
      );
      // And the fabrication screen shows the glass first too.
      expect(InputBlockOrder.arrange(merged, d.toSet()).first,
          InputBlockOrder.glassColor);
    });

    test('they follow that part when it moves', () {
      // The unit row dragged to the very bottom of an estimate.
      final Set<String> estimate = d
          .where(
            (String id) =>
                id != InputBlockOrder.lock && id != InputBlockOrder.rubber,
          )
          .toSet();
      final List<String> shown = InputBlockOrder.arrange(d, estimate);
      final List<String> moved = <String>[
        ...shown.where((String id) => id != InputBlockOrder.unit),
        InputBlockOrder.unit,
      ];
      final List<String> merged = InputBlockOrder.merge(d, moved);
      expect(merged.sublist(merged.length - 3), <String>[
        InputBlockOrder.unit,
        InputBlockOrder.lock,
        InputBlockOrder.rubber,
      ]);
    });

    test('a hidden part before every shown one stays at the top', () {
      final Set<String> noCollar = d
          .where((String id) => id != InputBlockOrder.collar)
          .toSet();
      final List<String> shown = InputBlockOrder.arrange(d, noCollar);
      final List<String> merged = InputBlockOrder.merge(d, <String>[
        ...shown.reversed,
      ]);
      expect(merged.first, InputBlockOrder.collar);
      expect(merged.length, d.length);
    });

    test('moving nothing changes nothing', () {
      expect(InputBlockOrder.merge(d, d), d);
      expect(InputBlockOrder.isDefault(InputBlockOrder.merge(d, d)), isTrue);
    });

    test('a moved order is no longer the default', () {
      final List<String> moved = <String>[...d.reversed];
      expect(InputBlockOrder.isDefault(InputBlockOrder.merge(d, moved)), isFalse);
    });
  });
}
