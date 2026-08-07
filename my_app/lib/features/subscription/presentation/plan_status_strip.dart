import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/subscription_api_client.dart';
import '../models/subscription_models.dart';
import 'subscription_gate_screen.dart';

/// How long is left, and on what.
///
/// Pulled out of [SubscriptionStatus] so the strip has one thing to render and
/// the "what does this mean" reasoning lives in one place rather than being
/// spread through the widget tree.
class PlanRemaining {
  final String title;
  final int daysLeft;

  /// How much of the period has been used, 0..1. Null when the length of the
  /// period is unknown, in which case no bar is drawn -- an invented bar would
  /// be worse than none.
  final double? usedFraction;

  /// True once the user has nothing left and has to pay to carry on.
  final bool ended;

  const PlanRemaining({
    required this.title,
    required this.daysLeft,
    this.usedFraction,
    this.ended = false,
  });

  /// Below this the strip turns amber: close enough that the owner should be
  /// deciding, far enough that they still can.
  static const int warningDays = 3;

  bool get isWarning => !ended && daysLeft <= warningDays;

  /// Whole days from now until [end], never negative.
  static int _daysUntil(DateTime? end) {
    if (end == null) return 0;
    final int hours = end.difference(DateTime.now()).inHours;
    if (hours <= 0) return 0;
    return (hours / 24).ceil();
  }

  static double? _used(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    final int total = end.difference(start).inMinutes;
    if (total <= 0) return null;
    final int gone = DateTime.now().difference(start).inMinutes;
    return (gone / total).clamp(0.0, 1.0);
  }

  /// Reads the status the same way the gate does, so the strip can never say
  /// something the paywall would contradict.
  static PlanRemaining? from(SubscriptionStatus status) {
    final TrialStatus? trial = status.trial;
    final UserSubscription? subscription = status.subscription;

    if (status.entitlement == 'subscription' && subscription != null) {
      final int left = _daysUntil(subscription.expiresAt);
      return PlanRemaining(
        title: status.plan?.title.trim().isNotEmpty ?? false
            ? status.plan!.title
            : 'Your plan',
        daysLeft: left,
        usedFraction: _used(subscription.startsAt, subscription.expiresAt),
        ended: left <= 0,
      );
    }

    if (status.entitlement == 'trial' && (trial?.active ?? false)) {
      // The server's own count wins: it knows when the trial was granted, and
      // a phone with a wrong clock should not shorten or extend it.
      final int left = trial!.daysRemaining > 0
          ? trial.daysRemaining
          : _daysUntil(trial.expiresAt);
      return PlanRemaining(
        title: 'Free trial',
        daysLeft: left,
        usedFraction: _used(trial.startsAt, trial.expiresAt),
        ended: left <= 0,
      );
    }

    // Nothing running: either the trial finished or a plan lapsed.
    if (!status.active) {
      return const PlanRemaining(
        title: 'No active plan',
        daysLeft: 0,
        ended: true,
      );
    }

    return null;
  }
}

/// A slim band across the top of Home saying what the user is on and how long
/// is left.
///
/// It answers the question people were opening Settings to ask, and it answers
/// it before they have to ask -- which matters most in the last few days, when
/// the answer changes what they do next. Tapping it opens Billing & Plans.
class PlanStatusStrip extends StatefulWidget {
  /// Injected in tests; the real screen lets it build its own client.
  final SubscriptionApiClient? apiClient;

  const PlanStatusStrip({super.key, this.apiClient});

  @override
  State<PlanStatusStrip> createState() => _PlanStatusStripState();
}

class _PlanStatusStripState extends State<PlanStatusStrip> {
  late final SubscriptionApiClient _client =
      widget.apiClient ?? SubscriptionApiClient();

  PlanRemaining? _remaining;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final SubscriptionStatus status = await _client.fetchStatus();
      if (!mounted) return;
      setState(() {
        _remaining = PlanRemaining.from(status);
        _loading = false;
      });
    } catch (_) {
      // Offline, or the service is having a moment. Home must still open, and
      // an alarming red band about an unknown plan would be worse than
      // showing nothing.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openBilling() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SubscriptionGateScreen.manage(),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final PlanRemaining? remaining = _remaining;
    if (_loading || remaining == null) {
      return const SizedBox.shrink();
    }

    final Color accent = remaining.ended
        ? AppTheme.danger
        : remaining.isWarning
        ? AppTheme.amberAccent
        : AppTheme.royalBlue;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space5),
      child: Material(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: _openBilling,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  remaining.ended
                      ? Icons.lock_clock_rounded
                      : Icons.hourglass_bottom_rounded,
                  size: 20,
                  color: accent,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              remaining.title,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _daysLabel(remaining),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                ),
                          ),
                        ],
                      ),
                      if (remaining.usedFraction != null) ...<Widget>[
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            // Shown as time left, not time spent: a bar that
                            // empties matches what the number beside it says.
                            value: 1 - remaining.usedFraction!,
                            minHeight: 5,
                            backgroundColor: accent.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: accent.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _daysLabel(PlanRemaining remaining) {
    if (remaining.ended) return 'Ended';
    if (remaining.daysLeft == 1) return '1 day left';
    return '${remaining.daysLeft} days left';
  }
}
