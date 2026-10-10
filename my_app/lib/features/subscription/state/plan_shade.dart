import 'package:flutter/foundation.dart';

import '../models/home_plan_look.dart';

/// The shade the shop's plan paints the app in: green while it runs, yellow
/// in its last days, red once it has ended. Null for a shop that has never
/// had a plan, which keeps the plain background.
///
/// Home used to wear it alone. Hashir (Oct 2026) wanted it on every screen
/// with a background, so it is held here, once, for all of them: Home reads
/// the plan (on opening and whenever the app comes back to the front) and
/// sets it, and every background listens.
class PlanShade extends ValueNotifier<PlanTone?> {
  PlanShade._() : super(null);

  static final PlanShade instance = PlanShade._();

  /// Signed out: the next account on this handset is somebody else, and
  /// must not open the app in the last shop's colour.
  void clear() => value = null;
}
