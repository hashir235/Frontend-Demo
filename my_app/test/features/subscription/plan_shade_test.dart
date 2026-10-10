import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/subscription/models/home_plan_look.dart';
import 'package:my_app/features/subscription/presentation/plan_tint.dart';
import 'package:my_app/features/subscription/presentation/plan_validity_card.dart';
import 'package:my_app/features/subscription/state/plan_shade.dart';
import 'package:my_app/shared/widgets/app_screen_shell.dart';

/// The plan's shade is on every screen with a background, not only Home:
/// the shared page shell, a screen that paints its own gradient, and every
/// plain Scaffold through the theme.
void main() {
  setUp(PlanShade.instance.clear);
  tearDown(PlanShade.instance.clear);

  Color? colourOf(WidgetTester tester, String key) {
    final AnimatedContainer box = tester.widget<AnimatedContainer>(
      find.byKey(Key(key)),
    );
    final Color? color = (box.decoration as BoxDecoration?)?.color;
    return color == Colors.transparent ? null : color;
  }

  group('a screen on the shared page shell', () {
    Future<void> open(WidgetTester tester, {Color? tint}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppScreenShell(tint: tint, child: const Text('Rates')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('wears the plan shade, and follows it as it changes', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(colourOf(tester, 'screen_shell_tint'), isNull);

      PlanShade.instance.value = PlanTone.active;
      await tester.pumpAndSettle();
      expect(
        colourOf(tester, 'screen_shell_tint'),
        planToneTint(PlanTone.active),
      );

      PlanShade.instance.value = PlanTone.endingSoon;
      await tester.pumpAndSettle();
      expect(
        colourOf(tester, 'screen_shell_tint'),
        planToneTint(PlanTone.endingSoon),
      );

      PlanShade.instance.value = PlanTone.ended;
      await tester.pumpAndSettle();
      expect(
        colourOf(tester, 'screen_shell_tint'),
        planToneTint(PlanTone.ended),
      );

      // Signed out.
      PlanShade.instance.clear();
      await tester.pumpAndSettle();
      expect(colourOf(tester, 'screen_shell_tint'), isNull);
    });

    testWidgets('a colour given to the shell still wins', (
      WidgetTester tester,
    ) async {
      PlanShade.instance.value = PlanTone.active;
      await open(tester, tint: Colors.purple);
      expect(colourOf(tester, 'screen_shell_tint'), Colors.purple);
    });
  });

  group('a screen with a gradient of its own', () {
    testWidgets('gets the shade over its gradient, under its content', (
      WidgetTester tester,
    ) async {
      PlanShade.instance.value = PlanTone.active;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              decoration: AppTheme.pageDecoration(),
              child: const PlanTint(child: Text('Settings')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(colourOf(tester, 'plan_tint'), planToneTint(PlanTone.active));
      // The content stands on the shade, not under it.
      expect(
        find.descendant(
          of: find.byKey(const Key('plan_tint')),
          matching: find.text('Settings'),
        ),
        findsOneWidget,
      );

      PlanShade.instance.clear();
      await tester.pumpAndSettle();
      expect(colourOf(tester, 'plan_tint'), isNull);
    });
  });

  group('every plain Scaffold, through the theme', () {
    test('no plan: the theme is left exactly as it was', () {
      final ThemeData theme = AppTheme.current();
      expect(identical(withPlanShade(theme, null), theme), isTrue);
    });

    test('a plan: the page colour carries its shade', () {
      final ThemeData theme = AppTheme.current();
      for (final PlanTone tone in PlanTone.values) {
        final ThemeData shaded = withPlanShade(theme, tone);
        expect(
          shaded.scaffoldBackgroundColor,
          Color.alphaBlend(planToneTint(tone), theme.scaffoldBackgroundColor),
          reason: '$tone',
        );
        expect(
          shaded.scaffoldBackgroundColor,
          isNot(theme.scaffoldBackgroundColor),
        );
        // Nothing else about the theme moves.
        expect(shaded.colorScheme, theme.colorScheme);
        expect(shaded.cardColor, theme.cardColor);
      }
    });

    testWidgets('a Scaffold with no background of its own shows it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: withPlanShade(AppTheme.current(), PlanTone.endingSoon),
          home: const Scaffold(body: Text('Notifications')),
        ),
      );
      final Material page = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        page.color,
        Color.alphaBlend(
          planToneTint(PlanTone.endingSoon),
          AppTheme.current().scaffoldBackgroundColor,
        ),
      );
    });
  });
}
