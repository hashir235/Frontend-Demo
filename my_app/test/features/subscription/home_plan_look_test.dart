import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/core/network/auth_http_client.dart';
import 'package:my_app/features/home/presentation/home_screen.dart';
import 'package:my_app/features/subscription/data/subscription_api_client.dart';
import 'package:my_app/features/subscription/models/home_plan_look.dart';
import 'package:my_app/features/subscription/models/subscription_models.dart';
import 'package:my_app/features/subscription/presentation/plan_validity_card.dart';
import 'package:my_app/features/tutorial/tutorial_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home shows a shop's plan at its foot and takes the plan's colour: green
/// while it runs, yellow in its last ten days, red once it has ended and not
/// been renewed. Anyone who never had a plan keeps the usual Home.
void main() {
  final DateTime now = DateTime.utc(2026, 9, 26, 10);

  Map<String, dynamic> statusJson({
    String entitlement = 'subscription',
    DateTime? expiresAt,
    bool withSubscription = true,
    String planTitle = '1 Year',
  }) => <String, dynamic>{
    'active': true,
    'entitlement': entitlement,
    'plan': <String, dynamic>{'id': 'p', 'title': planTitle},
    'subscription': withSubscription
        ? <String, dynamic>{
            'id': 's',
            'startsAt': now.subtract(const Duration(days: 30)).toIso8601String(),
            'expiresAt': expiresAt?.toIso8601String(),
          }
        : null,
    'trial': null,
    'enforcementMode': 'preview',
  };

  HomePlanLook? lookFor(Map<String, dynamic> json) =>
      HomePlanLook.from(SubscriptionStatus.fromJson(json), now: now);

  group('which look a plan gets', () {
    test('no plan ever bought: nothing to show', () {
      expect(lookFor(statusJson(withSubscription: false, entitlement: 'trial')), isNull);
      expect(lookFor(statusJson(withSubscription: false, entitlement: 'none')), isNull);
    });

    test('a plan with more than ten days left is green', () {
      final HomePlanLook look = lookFor(
        statusJson(expiresAt: now.add(const Duration(days: 200))),
      )!;
      expect(look.tone, PlanTone.active);
      expect(look.daysLeft, 200);
      expect(look.planLabel, '1 Year plan');
    });

    test('eleven days left is still green, ten turns yellow', () {
      expect(
        lookFor(statusJson(expiresAt: now.add(const Duration(days: 11))))!.tone,
        PlanTone.active,
      );
      final HomePlanLook ten = lookFor(
        statusJson(expiresAt: now.add(const Duration(days: 10))),
      )!;
      expect(ten.tone, PlanTone.endingSoon);
      expect(ten.daysLabel, '10 days left');
    });

    test('the last few hours count as a day, and are yellow', () {
      final HomePlanLook look = lookFor(
        statusJson(expiresAt: now.add(const Duration(hours: 3))),
      )!;
      expect(look.tone, PlanTone.endingSoon);
      expect(look.daysLabel, '1 day left');
    });

    test('an ended plan that was not renewed is red', () {
      final HomePlanLook look = lookFor(
        statusJson(
          entitlement: 'none',
          expiresAt: now.subtract(const Duration(days: 2)),
        ),
      )!;
      expect(look.tone, PlanTone.ended);
      expect(look.daysLabel, 'Ended');
      expect(look.dateLine, startsWith('Ended on '));
    });

    test('a plan the server no longer counts is red, whatever its date', () {
      // Stopped from the panel: the row is kept, the server says "none".
      expect(
        lookFor(
          statusJson(
            entitlement: 'none',
            expiresAt: now.add(const Duration(days: 40)),
          ),
        )!.tone,
        PlanTone.ended,
      );
    });

    test('a running plan whose date has just passed is red', () {
      expect(
        lookFor(statusJson(expiresAt: now.subtract(const Duration(minutes: 1))))!
            .tone,
        PlanTone.ended,
      );
    });

    test('a lifetime account shows a running plan, never an ended one', () {
      expect(
        lookFor(
          statusJson(
            entitlement: 'lifetime',
            expiresAt: now.add(const Duration(days: 70)),
          ),
        )!.tone,
        PlanTone.active,
      );
      expect(
        lookFor(
          statusJson(
            entitlement: 'lifetime',
            expiresAt: now.subtract(const Duration(days: 5)),
          ),
        ),
        isNull,
      );
    });

    test('the date is written out the way the receipt writes it', () {
      expect(HomePlanLook.formatLongDate(DateTime(2026, 12, 11)), '11 December 2026');
      final HomePlanLook look = lookFor(
        statusJson(expiresAt: DateTime(2027, 9, 26, 12)),
      )!;
      expect(look.dateLine, 'Valid till 26 September 2027');
    });

    test('a plan called "... plan" is not called "plan plan"', () {
      expect(
        lookFor(
          statusJson(
            planTitle: 'Starter Plan',
            expiresAt: now.add(const Duration(days: 30)),
          ),
        )!.planLabel,
        'Starter Plan',
      );
    });
  });

  group('Home', () {
    Future<void> openHome(WidgetTester tester, Map<String, dynamic>? json) async {
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final SubscriptionApiClient client = SubscriptionApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient((http.Request request) async {
          if (json == null) return http.Response('offline', 503);
          return http.Response(jsonEncode(json), 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            authClient: AuthHttpClient(
              MockClient(
                (http.Request request) async => http.Response('{}', 200),
              ),
            ),
            subscriptionClient: client,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Color? tint(WidgetTester tester) {
      final AnimatedContainer box = tester.widget<AnimatedContainer>(
        find.byKey(const Key('screen_shell_tint')),
      );
      final Color? color = (box.decoration as BoxDecoration?)?.color;
      return color == Colors.transparent ? null : color;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // Home would otherwise start the first-run tour over the test.
      await TutorialController.instance.markSeen();
    });

    testWidgets('a running plan: green Home, plan and date at the foot', (
      WidgetTester tester,
    ) async {
      await openHome(
        tester,
        statusJson(expiresAt: DateTime.now().add(const Duration(days: 120))),
      );
      expect(find.byKey(const Key('home_plan_card')), findsOneWidget);
      expect(find.text('1 Year plan'), findsOneWidget);
      expect(find.textContaining('Valid till '), findsOneWidget);
      expect(tint(tester), planToneTint(PlanTone.active));
    });

    testWidgets('ten days left: yellow Home', (WidgetTester tester) async {
      await openHome(
        tester,
        statusJson(expiresAt: DateTime.now().add(const Duration(days: 9, hours: 5))),
      );
      expect(find.text('10 days left'), findsOneWidget);
      expect(tint(tester), planToneTint(PlanTone.endingSoon));
    });

    testWidgets('ended and not renewed: red Home', (WidgetTester tester) async {
      await openHome(
        tester,
        statusJson(
          entitlement: 'none',
          expiresAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );
      expect(find.text('Ended'), findsOneWidget);
      expect(find.textContaining('Ended on '), findsOneWidget);
      expect(tint(tester), planToneTint(PlanTone.ended));
    });

    testWidgets('no plan bought: the usual Home, no card', (
      WidgetTester tester,
    ) async {
      await openHome(
        tester,
        statusJson(withSubscription: false, entitlement: 'trial'),
      );
      expect(find.byKey(const Key('home_plan_card')), findsNothing);
      expect(tint(tester), isNull);
    });

    testWidgets('offline: the usual Home, nothing guessed', (
      WidgetTester tester,
    ) async {
      await openHome(tester, null);
      expect(find.byKey(const Key('home_plan_card')), findsNothing);
      expect(tint(tester), isNull);
    });
  });
}
