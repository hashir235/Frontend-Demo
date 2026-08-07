import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/subscription/models/subscription_models.dart';
import 'package:my_app/features/subscription/presentation/plan_status_strip.dart';

/// The strip on Home answers "how long have I got left". Getting that number
/// wrong is worse than not showing it: someone who thinks they have a week
/// when they have a day loses a working morning to a locked app.
SubscriptionStatus _status({
  required String entitlement,
  bool active = true,
  TrialStatus? trial,
  UserSubscription? subscription,
  SubscriptionPlan? plan,
}) {
  return SubscriptionStatus(
    active: active,
    entitlement: entitlement,
    plan: plan,
    subscription: subscription,
    trial: trial,
    trialDays: 15,
    enforcementMode: 'strict',
    googlePlayConfigured: true,
    packageName: 'com.quickal.app',
  );
}

UserSubscription _sub({DateTime? startsAt, DateTime? expiresAt}) {
  return UserSubscription(
    id: 's1',
    planId: 'monthly',
    productId: 'p',
    provider: 'direct_website',
    state: 'active',
    autoRenewing: false,
    startsAt: startsAt,
    expiresAt: expiresAt,
  );
}

void main() {
  final DateTime now = DateTime.now();

  group('trial', () {
    test('uses the server day count rather than the phone clock', () {
      // A phone with a wrong date must not lengthen or shorten a trial.
      final PlanRemaining? out = PlanRemaining.from(
        _status(
          entitlement: 'trial',
          trial: TrialStatus(
            active: true,
            startsAt: now.subtract(const Duration(days: 7)),
            expiresAt: now.add(const Duration(days: 8)),
            daysRemaining: 8,
          ),
        ),
      );

      expect(out, isNotNull);
      expect(out!.title, 'Free trial');
      expect(out.daysLeft, 8);
      expect(out.ended, isFalse);
    });

    test('falls back to the expiry date when the count is missing', () {
      final PlanRemaining? out = PlanRemaining.from(
        _status(
          entitlement: 'trial',
          trial: TrialStatus(
            active: true,
            startsAt: now.subtract(const Duration(days: 13)),
            expiresAt: now.add(const Duration(days: 2)),
            daysRemaining: 0,
          ),
        ),
      );

      expect(out!.daysLeft, 2);
    });

    test('the last few days raise a warning', () {
      final PlanRemaining? out = PlanRemaining.from(
        _status(
          entitlement: 'trial',
          trial: TrialStatus(
            active: true,
            startsAt: now.subtract(const Duration(days: 13)),
            expiresAt: now.add(const Duration(days: 2)),
            daysRemaining: 2,
          ),
        ),
      );

      expect(out!.isWarning, isTrue);
    });

    test('a long way out does not', () {
      final PlanRemaining? out = PlanRemaining.from(
        _status(
          entitlement: 'trial',
          trial: TrialStatus(
            active: true,
            startsAt: now.subtract(const Duration(days: 1)),
            expiresAt: now.add(const Duration(days: 14)),
            daysRemaining: 14,
          ),
        ),
      );

      expect(out!.isWarning, isFalse);
    });
  });

  group('paid plan', () {
    test('counts the days to expiry and names the plan', () {
      final PlanRemaining? out = PlanRemaining.from(
        _status(
          entitlement: 'subscription',
          plan: const SubscriptionPlan(
            id: 'monthly',
            productId: 'p',
            title: 'Monthly',
            durationLabel: '1 month',
            pricePkr: 1000,
            savingsLabel: '',
            sortOrder: 1,
            channel: 'direct_website',
          ),
          subscription: _sub(
            startsAt: now.subtract(const Duration(days: 7)),
            expiresAt: now.add(const Duration(days: 23)),
          ),
        ),
      );

      expect(out!.title, 'Monthly');
      expect(out.daysLeft, 23);
      expect(out.ended, isFalse);
    });

    test('the bar reflects how much of the period is gone', () {
      final PlanRemaining? out = PlanRemaining.from(
        _status(
          entitlement: 'subscription',
          subscription: _sub(
            startsAt: now.subtract(const Duration(days: 15)),
            expiresAt: now.add(const Duration(days: 15)),
          ),
        ),
      );

      expect(out!.usedFraction, closeTo(0.5, 0.02));
    });

    test('no dates means no bar rather than an invented one', () {
      final PlanRemaining? out = PlanRemaining.from(
        _status(entitlement: 'subscription', subscription: _sub()),
      );

      expect(out!.usedFraction, isNull);
    });

    test('an expired plan reads as ended, never as negative days', () {
      final PlanRemaining? out = PlanRemaining.from(
        _status(
          entitlement: 'subscription',
          subscription: _sub(
            startsAt: now.subtract(const Duration(days: 40)),
            expiresAt: now.subtract(const Duration(days: 3)),
          ),
        ),
      );

      expect(out!.ended, isTrue);
      expect(out.daysLeft, 0);
    });
  });

  group('nothing running', () {
    test('an inactive account says so plainly', () {
      final PlanRemaining? out = PlanRemaining.from(
        _status(entitlement: 'none', active: false),
      );

      expect(out!.ended, isTrue);
      expect(out.title, 'No active plan');
      expect(out.isWarning, isFalse, reason: 'ended is not a warning state');
    });
  });

  testWidgets('nothing is shown while the status is still loading', (
    WidgetTester tester,
  ) async {
    // Home has to open instantly. A strip that flashes in half-drawn, or an
    // alarming band about a plan we have not fetched yet, is worse than
    // nothing.
    await tester.pumpWidget(const MaterialApp(home: PlanStatusStrip()));
    await tester.pump();

    expect(find.byType(PlanStatusStrip), findsOneWidget);
    expect(find.textContaining('days left'), findsNothing);
  });
}
