import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tutorial_step.dart';
import 'tutorial_steps_estimation.dart';

/// Drives the guided tour.
///
/// The tour spans several screens, so the running state lives here rather than
/// in any one screen's State. Screens register their highlightable widgets with
/// [registerTarget]; the overlay reads [currentStep] and only paints once the
/// step's screen is the one showing.
class TutorialController extends ChangeNotifier {
  TutorialController._internal();

  static final TutorialController instance = TutorialController._internal();

  /// Set once the user has seen (or skipped) the tour, so it does not reappear
  /// on every launch. AppSettings is memory-only, so this goes to disk itself.
  static const String _seenKey = 'quick_al.tutorial.estimation_seen.v1';

  List<TutorialStep> _steps = const <TutorialStep>[];
  int _index = 0;
  bool _running = false;

  /// Which screen is currently on top. Screens report this on build so the
  /// overlay knows whether the current step belongs to them.
  TutorialScreen? _visibleScreen;

  final Map<String, GlobalKey> _targets = <String, GlobalKey>{};

  bool get isRunning => _running;
  int get index => _index;
  int get stepCount => _steps.length;

  TutorialStep? get currentStep =>
      _running && _index < _steps.length ? _steps[_index] : null;

  /// The step to paint right now, or null when the current step belongs to a
  /// screen the user has not reached yet.
  TutorialStep? get visibleStep {
    final TutorialStep? step = currentStep;
    if (step == null || _visibleScreen == null) return null;
    return step.screen == _visibleScreen ? step : null;
  }

  GlobalKey? targetKey(String? id) => id == null ? null : _targets[id];

  // --- screens ---

  void setVisibleScreen(TutorialScreen screen) {
    if (_visibleScreen == screen) return;
    _visibleScreen = screen;
    if (_running) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  void clearVisibleScreen(TutorialScreen screen) {
    if (_visibleScreen != screen) return;
    _visibleScreen = null;
  }

  // --- targets ---

  void registerTarget(String id, GlobalKey key) {
    if (_targets[id] == key) return;
    _targets[id] = key;
    if (_running) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  void unregisterTarget(String id, GlobalKey key) {
    if (_targets[id] == key) _targets.remove(id);
  }

  // --- running ---

  void start({List<TutorialStep>? steps}) {
    _steps = steps ?? estimationTutorialSteps;
    _index = 0;
    _running = true;
    notifyListeners();
  }

  void next() {
    if (!_running) return;
    if (_index + 1 >= _steps.length) {
      finish();
      return;
    }
    _index += 1;
    notifyListeners();
  }

  void back() {
    if (!_running || _index == 0) return;
    _index -= 1;
    notifyListeners();
  }

  /// Called when the user taps a highlighted widget on a `requiresTap` step.
  /// The tap itself still reaches the widget, so the app moves on as usual.
  void advanceAfterTap() {
    final TutorialStep? step = currentStep;
    if (step == null || !step.requiresTap) return;
    next();
  }

  void skip() => finish();

  void finish() {
    _running = false;
    _index = 0;
    notifyListeners();
    unawaitedMarkSeen();
  }

  // --- persistence ---

  Future<bool> hasSeen() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      // Storage unavailable -- better to offer the tour again than to crash.
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {
      // Not worth interrupting anyone over; the tour simply offers itself
      // again next launch.
    }
  }

  /// Fire-and-forget wrapper so [finish] stays synchronous for callers.
  void unawaitedMarkSeen() {
    markSeen();
  }

  /// Clears the flag so the tour plays again on next launch. Handy for testing
  /// and for a "show me again from the start" option later.
  Future<void> resetSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenKey);
  }
}
