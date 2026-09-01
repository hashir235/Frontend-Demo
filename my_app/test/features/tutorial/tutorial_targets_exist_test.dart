import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/tutorial/tutorial_step.dart';
import 'package:my_app/features/tutorial/tutorial_steps_estimation.dart';
import 'package:my_app/features/tutorial/tutorial_steps_fabrication.dart';

/// Guards the failure that keeps coming back: a step points at something no
/// screen ever registered, so the tour shows its bubble with no spotlight and
/// the user is told to look at a thing that is not highlighted.
///
/// This reads the source rather than pumping widgets on purpose -- pumping
/// every screen in the flow needs a signed-in session and a live backend,
/// while the wiring mistake is plainly visible in the source.
void main() {
  late final String libSource;

  setUpAll(() {
    final StringBuffer buffer = StringBuffer();
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        buffer.writeln(entity.readAsStringSync());
      }
    }
    libSource = buffer.toString();
  });

  /// Every id handed to a TutorialTarget anywhere under lib/ -- either
  /// directly as `id:`, or through a builder's `tourId:` parameter.
  ///
  /// Some ids are chosen by a conditional (`id: index == 0 ? 'a' : 'b'`), so
  /// this reads a short stretch after the parameter name and collects every
  /// string literal in it rather than insisting the literal comes first.
  Set<String> registeredIds() {
    final Set<String> ids = <String>{};
    final RegExp literal = RegExp(r"""'([^'\n]+)'""");
    for (final RegExpMatch match in RegExp(
      r'\b(?:id|tourId):',
    ).allMatches(libSource)) {
      final int start = match.end;
      final int end = (start + 160).clamp(0, libSource.length);
      for (final RegExpMatch found in literal.allMatches(
        libSource.substring(start, end),
      )) {
        ids.add(found.group(1)!);
      }
    }
    return ids;
  }

  const Map<String, List<TutorialStep>> tours = <String, List<TutorialStep>>{
    'estimation': estimationTutorialSteps,
    'fabrication': fabricationTutorialSteps,
  };

  for (final MapEntry<String, List<TutorialStep>> tour in tours.entries) {
    test('${tour.key}: every step that names a target points at one that '
        'exists', () {
      final Set<String> registered = registeredIds();
      final List<String> missing = <String>[];

      for (final TutorialStep step in tour.value) {
        final String? id = step.targetId;
        if (id != null && !registered.contains(id)) {
          missing.add('${step.screen.name}: $id ("${step.title}")');
        }
      }

      expect(
        missing,
        isEmpty,
        reason:
            'These steps point at widgets no TutorialTarget registers, so '
            'they would show a bubble with nothing highlighted:\n'
            '${missing.join('\n')}',
      );
    });

    test('${tour.key}: a step that asks for a tap names the thing to tap', () {
      // requiresTap hides the Next button, so a step without a target would
      // strand the user on a dimmed screen with no way forward. The overlay
      // has a fallback for this, but reaching that fallback is a mistake.
      final List<String> untargeted = tour.value
          .where((TutorialStep s) => s.requiresTap && s.targetId == null)
          .map((TutorialStep s) => '${s.screen.name}: "${s.title}"')
          .toList();

      expect(untargeted, isEmpty);
    });
  }

  test('the two tours keep their own "seen" flags', () {
    // One flag for both would mean seeing the Estimation walkthrough silences
    // the Fabrication one, which a fabrication-only user would never ask for.
    expect(TutorialTour.values, hasLength(2));
  });

  test('fabrication ends at the glass report, not at a bill', () {
    final Set<TutorialScreen> covered = fabricationTutorialSteps
        .map((TutorialStep s) => s.screen)
        .toSet();

    expect(covered, contains(TutorialScreen.fabricationMenu));
    expect(covered, contains(TutorialScreen.materialTable));
    // Fabrication has no billing step -- that flow simply does not exist here.
    expect(covered, isNot(contains(TutorialScreen.billInputs)));
    expect(covered, isNot(contains(TutorialScreen.actualBill)));
  });

  test('the estimation tour reaches the end of the flow', () {
    final Set<TutorialScreen> covered = estimationTutorialSteps
        .map((TutorialStep s) => s.screen)
        .toSet();

    // The tour died at Estimation once because the screens after it were
    // never written into the script.
    expect(
      covered,
      containsAll(<TutorialScreen>[
        TutorialScreen.home,
        TutorialScreen.projectMenu,
        TutorialScreen.windowLibrary,
        TutorialScreen.windowInput,
        TutorialScreen.reviewList,
        TutorialScreen.lengthOptimization,
        TutorialScreen.sectionRecalculation,
        TutorialScreen.rateSetting,
        TutorialScreen.materialTable,
        TutorialScreen.billInputs,
        TutorialScreen.actualBill,
      ]),
    );
  });
}
