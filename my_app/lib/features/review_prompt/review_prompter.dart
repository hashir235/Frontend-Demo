import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Decides when -- and whether -- to ask the user for a rating.
///
/// Asking is cheap for us and costs the user their attention, so the rules are
/// deliberately conservative: not until they have had the app a while, never
/// twice in the same month, and never again once they have said no or actually
/// rated it. A prompt that keeps coming back earns one-star reviews, which is
/// the opposite of the point.
class ReviewPrompter {
  ReviewPrompter({InAppReview? review, SharedPreferences? prefs})
    : _review = review ?? InAppReview.instance,
      _injectedPrefs = prefs;

  final InAppReview _review;
  final SharedPreferences? _injectedPrefs;

  static const String _firstSeenKey = 'quick_al.review.first_seen';
  static const String _lastAskedKey = 'quick_al.review.last_asked';
  static const String _settledKey = 'quick_al.review.settled';

  /// A week of ownership before the first ask. Long enough that they have
  /// finished real jobs and have an opinion worth leaving.
  static const int daysBeforeFirstAsk = 7;

  /// If they choose "later", that is a no for now -- not a no forever.
  static const int daysBetweenAsks = 30;

  static const String storeUrl =
      'https://play.google.com/store/apps/details?id=com.quickal.app';

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  /// Records the first time the app was opened, so the clock starts from
  /// install rather than from whenever this feature shipped.
  Future<void> noteAppOpened() async {
    try {
      final SharedPreferences prefs = await _prefs;
      if (prefs.getInt(_firstSeenKey) == null) {
        await prefs.setInt(
          _firstSeenKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (_) {
      // Storage is not worth interrupting anyone over; we simply ask later.
    }
  }

  /// Whether the moment is right to ask.
  Future<bool> shouldAsk() async {
    try {
      final SharedPreferences prefs = await _prefs;
      if (prefs.getBool(_settledKey) ?? false) return false;

      final int? firstSeen = prefs.getInt(_firstSeenKey);
      // Nothing recorded yet means this is the first open; start the clock and
      // do not ask a user who has had the app for ten seconds.
      if (firstSeen == null) {
        await noteAppOpened();
        return false;
      }

      final DateTime since = DateTime.fromMillisecondsSinceEpoch(firstSeen);
      if (_daysSince(since) < daysBeforeFirstAsk) return false;

      final int? lastAsked = prefs.getInt(_lastAskedKey);
      if (lastAsked != null) {
        final DateTime asked = DateTime.fromMillisecondsSinceEpoch(lastAsked);
        if (_daysSince(asked) < daysBetweenAsks) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// A phone clock that has jumped backwards would otherwise make "days since"
  /// negative and hold the prompt off forever.
  int _daysSince(DateTime moment) {
    final int days = DateTime.now().difference(moment).inDays;
    return days < 0 ? 0 : days;
  }

  /// Remember that we asked, so the next one is a month away.
  Future<void> noteAsked() async {
    try {
      final SharedPreferences prefs = await _prefs;
      await prefs.setInt(_lastAskedKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Worst case we ask again sooner than intended.
    }
  }

  /// Stop asking for good -- they rated, or they said no.
  Future<void> settle() async {
    try {
      final SharedPreferences prefs = await _prefs;
      await prefs.setBool(_settledKey, true);
    } catch (_) {
      // Same as above.
    }
  }

  /// Opens Google's own review card if it is available, otherwise the store
  /// listing.
  ///
  /// The native card keeps the user inside the app, but Google decides whether
  /// to show it and silently does nothing when its quota is spent. That is
  /// indistinguishable from success from our side, so a user who asked to rate
  /// must still end up somewhere they can.
  Future<bool> openReview() async {
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview();
        return true;
      }
    } catch (_) {
      // Fall through to the listing.
    }
    return openStoreListing();
  }

  Future<bool> openStoreListing() async {
    try {
      return await launchUrl(
        Uri.parse(storeUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  /// Test seam: wipes what we remember about asking.
  Future<void> resetForTesting() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove(_firstSeenKey);
    await prefs.remove(_lastAskedKey);
    await prefs.remove(_settledKey);
  }
}
