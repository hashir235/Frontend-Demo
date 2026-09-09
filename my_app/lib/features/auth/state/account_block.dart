import 'package:flutter/foundation.dart';

/// Whether this account has been switched off, and what its owner is told.
///
/// The reason is written per shop from the admin panel and travels with the
/// refusal, because it is never the same twice: a payment that has not cleared
/// reads nothing like a suspension, and "the app stopped working" sends
/// somebody to the phone with nothing to go on.
///
/// Held here rather than on the auth controller because the refusal can arrive
/// from any request, at any moment -- the account may be switched off while
/// the app is open and halfway through a job.
class AccountBlock extends ChangeNotifier {
  AccountBlock._();

  static final AccountBlock instance = AccountBlock._();

  String? _message;

  /// The owner's own words, or null while the account is fine.
  String? get message => _message;

  bool get isBlocked => _message != null;

  /// Called when the server refuses a request because the account is off.
  ///
  /// Repeated refusals with the same wording change nothing: every screen in
  /// the app can be making requests, and a notification per refusal would
  /// rebuild the block screen over and over.
  void raise(String message) {
    final String next = message.trim();
    if (next.isEmpty || _message == next) return;
    _message = next;
    notifyListeners();
  }

  /// Switched back on -- or signed out, which is the other way off this
  /// screen. Clearing on sign-out matters: the next person to sign in on this
  /// handset is a different account and must not meet somebody else's notice.
  void clear() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }
}
