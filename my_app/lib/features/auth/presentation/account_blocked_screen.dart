import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../state/account_block.dart';
import '../state/auth_controller.dart';

/// What a shop sees when their account has been switched off.
///
/// The whole point of this screen is the message on it. It is written for this
/// shop by the person who switched them off, and it is the difference between
/// "the app is broken" -- which sends somebody to the phone angry and with
/// nothing to go on -- and knowing that an invoice has not cleared.
///
/// Nothing is offered except signing out. There is no retry button because
/// there is nothing on this phone to retry: the account comes back when it is
/// switched back on, and the app finds that out by itself on the next open.
class AccountBlockedScreen extends StatelessWidget {
  final String message;

  const AccountBlockedScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      // No back button and nothing behind it: this is not a page of the app,
      // it is the app being unavailable.
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 38,
                      color: AppTheme.warning,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Account paused',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // The owner's own words, given the room to be read. Left
                  // exactly as written -- it may name an invoice, a date or a
                  // phone number, and trimming it would cut the useful half.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: SelectableText(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your work is safe. Nothing has been deleted, and '
                    'everything comes back when the account is switched on '
                    'again.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextButton(
                    key: const Key('blocked_sign_out_button'),
                    onPressed: () {
                      // Clearing the notice first: the account this handset
                      // signs into next is somebody else, and must not meet
                      // this shop's message.
                      AccountBlock.instance.clear();
                      AuthController.instance.signOut();
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
