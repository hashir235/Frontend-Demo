import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'review_prompter.dart';

/// What the user chose when asked for a rating.
enum ReviewChoice {
  /// Take me to the rating.
  rate,

  /// Not now -- ask again in a month.
  later,

  /// Never ask again.
  never,
}

/// Asks, once the user has had the app a while, whether they would rate it.
///
/// Three answers rather than two: "later" has to be a real option, or the only
/// way out of the dialog is a no we then treat as permanent. Dismissing it by
/// tapping outside counts as "later" for the same reason.
Future<ReviewChoice?> showReviewPromptDialog(BuildContext context) {
  return showDialog<ReviewChoice>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        icon: const Icon(
          Icons.star_rounded,
          color: AppTheme.amberAccent,
          size: 36,
        ),
        title: Text(
          'Is Quick AL working well for you?',
          textAlign: TextAlign.center,
          style: Theme.of(
            ctx,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'If it is, a rating helps other fabricators find it — and it only '
          'takes a moment.',
          textAlign: TextAlign.center,
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(ReviewChoice.rate),
                  icon: const Icon(Icons.star_rounded, size: 20),
                  label: const Text('Rate Quick AL'),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(ReviewChoice.later),
                  child: const Text('Maybe later'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(ReviewChoice.never),
                  child: const Text("Don't ask again"),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Runs the whole thing: decides whether to ask, asks, and acts on the answer.
///
/// Kept here rather than in the Home screen's State so the rules and the
/// dialog stay together, and Home only has to say "maybe now".
Future<void> maybeAskForReview(
  BuildContext context, {
  ReviewPrompter? prompter,
}) async {
  final ReviewPrompter reviewPrompter = prompter ?? ReviewPrompter();
  if (!await reviewPrompter.shouldAsk()) return;
  if (!context.mounted) return;

  // Written before the dialog opens, not after: someone who closes the app
  // mid-question has still been asked, and should not be asked again tomorrow.
  await reviewPrompter.noteAsked();
  if (!context.mounted) return;

  final ReviewChoice? choice = await showReviewPromptDialog(context);
  switch (choice) {
    case ReviewChoice.rate:
      await reviewPrompter.settle();
      await reviewPrompter.openReview();
    case ReviewChoice.never:
      await reviewPrompter.settle();
    case ReviewChoice.later:
    case null:
      // Dismissed by tapping outside counts as "later" -- noteAsked already
      // pushed the next one a month out.
      break;
  }
}
