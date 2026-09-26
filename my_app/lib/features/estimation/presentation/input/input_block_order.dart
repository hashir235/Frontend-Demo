/// The parts of the window input screen a shop can move, and the order they
/// stand in.
///
/// Every shop wants these somewhere different -- one wants the glass first,
/// another the sizes straight under the collar -- so rather than pick one
/// layout for everybody, each phone keeps its own. A part is held and dragged
/// up or down, as an app icon is on the phone's home screen.
///
/// One order for every window. A part a window does not have (the rubber on
/// an estimate, the lock on a fix window) is skipped there and keeps its place
/// for the windows that do.
class InputBlockOrder {
  const InputBlockOrder._();

  static const String collar = 'collar';
  static const String windowNo = 'windowNo';
  static const String dimensions = 'dimensions';
  static const String unit = 'unit';
  static const String lock = 'lock';
  static const String rubber = 'rubber';
  static const String perSide = 'perSide';
  static const String sizes = 'sizes';
  static const String gauge = 'gauge';
  static const String aluminiumColor = 'aluminiumColor';
  static const String glassColor = 'glassColor';
  static const String description = 'description';

  /// The screen as it stood before anybody moved anything.
  static const List<String> defaults = <String>[
    collar,
    windowNo,
    dimensions,
    unit,
    lock,
    rubber,
    perSide,
    sizes,
    gauge,
    aluminiumColor,
    glassColor,
    description,
  ];

  /// A saved order, made whole: anything unknown dropped, anything missing --
  /// a part added in a later version -- put back after the part it follows by
  /// default, so a new part turns up where it was designed to be.
  static List<String> resolve(List<String>? saved) {
    if (saved == null || saved.isEmpty) return List<String>.of(defaults);
    final List<String> order = <String>[];
    for (final String id in saved) {
      if (defaults.contains(id) && !order.contains(id)) order.add(id);
    }
    for (int i = 0; i < defaults.length; i++) {
      final String id = defaults[i];
      if (order.contains(id)) continue;
      int at = 0;
      for (int j = i - 1; j >= 0; j--) {
        final int before = order.indexOf(defaults[j]);
        if (before >= 0) {
          at = before + 1;
          break;
        }
      }
      order.insert(at, id);
    }
    return order;
  }

  /// The parts this window shows, in the saved order.
  static List<String> arrange(List<String> order, Set<String> shown) =>
      <String>[
        for (final String id in resolve(order))
          if (shown.contains(id)) id,
      ];

  /// The whole order after the parts on screen were rearranged into [moved].
  ///
  /// A part this window does not show stays with the shown part it followed,
  /// so the lock and rubber rows an estimate never shows are still right
  /// under the unit row when a fabrication window opens -- wherever the unit
  /// row has gone.
  static List<String> merge(List<String> order, List<String> moved) {
    final List<String> full = resolve(order);
    final Set<String> shown = moved.toSet();
    final Map<String?, List<String>> following = <String?, List<String>>{};
    String? anchor;
    for (final String id in full) {
      if (shown.contains(id)) {
        anchor = id;
      } else {
        following.putIfAbsent(anchor, () => <String>[]).add(id);
      }
    }
    return <String>[
      ...?following[null],
      for (final String id in moved) ...<String>[id, ...?following[id]],
    ];
  }

  /// Whether [order] is still the screen as it came.
  static bool isDefault(List<String> order) {
    final List<String> full = resolve(order);
    for (int i = 0; i < defaults.length; i++) {
      if (full[i] != defaults[i]) return false;
    }
    return true;
  }
}
