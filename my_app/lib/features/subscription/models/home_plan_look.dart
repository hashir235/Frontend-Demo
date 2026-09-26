import 'subscription_models.dart';

/// Where a shop's plan stands, as Home shows it.
enum PlanTone {
  /// Running, with more than [HomePlanLook.endingSoonDays] left.
  active,

  /// Running, but [HomePlanLook.endingSoonDays] or fewer days are left.
  endingSoon,

  /// Over, and not renewed.
  ended,
}

/// The plan card at the foot of Home, and the shade Home is painted in.
///
/// Only for a shop that has had a plan. Someone still on the free trial, or
/// on nothing at all, has no plan to show and keeps the usual Home.
class HomePlanLook {
  /// The plan's name, e.g. "1 Year".
  final String title;

  /// When the plan runs out (or ran out), on this phone's clock.
  final DateTime endsAt;

  /// Whole days left, counting a part day as one. Zero once it has ended.
  final int daysLeft;

  final PlanTone tone;

  const HomePlanLook({
    required this.title,
    required this.endsAt,
    required this.daysLeft,
    required this.tone,
  });

  /// From this many days left, Home turns yellow: time to renew.
  static const int endingSoonDays = 10;

  static HomePlanLook? from(SubscriptionStatus status, {DateTime? now}) {
    final UserSubscription? subscription = status.subscription;
    final DateTime? expiresAt = subscription?.expiresAt;
    if (subscription == null || expiresAt == null) return null;

    final DateTime at = now ?? DateTime.now();
    final bool beforeEnd = expiresAt.isAfter(at);
    // The server decides whether a plan counts (a stopped or refunded one does
    // not, whatever its date says). A lifetime account is reported as
    // "lifetime" instead, so for that one the date is all there is to go on.
    final bool lifetime = status.entitlement == 'lifetime';
    final bool running =
        beforeEnd && (status.entitlement == 'subscription' || lifetime);

    if (!running && lifetime) {
      // A lifetime account never runs out; an old plan under it is history.
      return null;
    }

    final String title = (status.plan?.title.trim().isNotEmpty ?? false)
        ? status.plan!.title.trim()
        : 'Your';

    if (!running) {
      return HomePlanLook(
        title: title,
        endsAt: expiresAt.toLocal(),
        daysLeft: 0,
        tone: PlanTone.ended,
      );
    }

    final int minutes = expiresAt.difference(at).inMinutes;
    final int daysLeft = minutes <= 0 ? 1 : (minutes / (24 * 60)).ceil();
    return HomePlanLook(
      title: title,
      endsAt: expiresAt.toLocal(),
      daysLeft: daysLeft,
      tone: daysLeft <= endingSoonDays ? PlanTone.endingSoon : PlanTone.active,
    );
  }

  /// "1 Year plan", "Monthly plan", "Your plan".
  String get planLabel =>
      title.toLowerCase().endsWith('plan') ? title : '$title plan';

  /// "Valid till 11 December 2026", or "Ended on 11 October 2026".
  String get dateLine => tone == PlanTone.ended
      ? 'Ended on ${formatLongDate(endsAt)}'
      : 'Valid till ${formatLongDate(endsAt)}';

  /// "12 days left", "1 day left", or "Ended".
  String get daysLabel {
    if (tone == PlanTone.ended) return 'Ended';
    return daysLeft == 1 ? '1 day left' : '$daysLeft days left';
  }

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// "11 December 2026" -- the way the receipt writes it.
  static String formatLongDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';
}
