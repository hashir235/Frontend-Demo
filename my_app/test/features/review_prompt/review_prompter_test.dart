import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/review_prompt/review_prompter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asking for a rating costs the user their attention and costs us nothing, so
/// the temptation is to ask often. That earns one-star reviews. These tests pin
/// the restraint: not for a week, never twice in a month, and never again once
/// they have answered for good.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ReviewPrompter prompter;

  DateTime daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

  Future<void> firstSeen(DateTime when) async {
    await prefs.setInt(
      'quick_al.review.first_seen',
      when.millisecondsSinceEpoch,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    prompter = ReviewPrompter(prefs: prefs);
  });

  test('a brand new user is not asked, and the clock starts', () async {
    expect(await prompter.shouldAsk(), isFalse);

    // The very first call also records the install moment, so the week is
    // counted from when they got the app rather than from whenever this
    // feature shipped.
    expect(prefs.getInt('quick_al.review.first_seen'), isNotNull);
  });

  test('still not asked partway through the first week', () async {
    await firstSeen(daysAgo(ReviewPrompter.daysBeforeFirstAsk - 1));
    expect(await prompter.shouldAsk(), isFalse);
  });

  test('asked once the week is up', () async {
    await firstSeen(daysAgo(ReviewPrompter.daysBeforeFirstAsk));
    expect(await prompter.shouldAsk(), isTrue);
  });

  test('not asked again the next day', () async {
    await firstSeen(daysAgo(30));
    await prompter.noteAsked();

    expect(await prompter.shouldAsk(), isFalse);
  });

  test('asked again a month later', () async {
    await firstSeen(daysAgo(90));
    await prefs.setInt(
      'quick_al.review.last_asked',
      daysAgo(ReviewPrompter.daysBetweenAsks).millisecondsSinceEpoch,
    );

    expect(await prompter.shouldAsk(), isTrue);
  });

  test('once settled, never again', () async {
    await firstSeen(daysAgo(365));
    await prompter.settle();

    expect(await prompter.shouldAsk(), isFalse);
  });

  test('a clock that jumped backwards does not freeze the prompt', () async {
    // A phone whose date is set into the future makes "days since install"
    // negative. Treating that as 0 keeps the prompt merely delayed rather than
    // permanently disabled.
    await firstSeen(DateTime.now().add(const Duration(days: 40)));

    expect(await prompter.shouldAsk(), isFalse);

    // And once the clock is sane again the normal rule applies.
    await firstSeen(daysAgo(ReviewPrompter.daysBeforeFirstAsk + 1));
    expect(await prompter.shouldAsk(), isTrue);
  });

  test('noteAppOpened does not move the clock on later launches', () async {
    final DateTime original = daysAgo(20);
    await firstSeen(original);

    await prompter.noteAppOpened();

    expect(
      prefs.getInt('quick_al.review.first_seen'),
      original.millisecondsSinceEpoch,
      reason: 'a later open must not restart the week',
    );
  });

  test('the store link points at the real listing', () {
    expect(ReviewPrompter.storeUrl, contains('id=com.quickal.app'));
    expect(ReviewPrompter.storeUrl, startsWith('https://'));
  });
}
