import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/core/network/auth_http_client.dart';
import 'package:my_app/features/auth/data/auth_api_client.dart';
import 'package:my_app/features/auth/models/auth_user.dart';
import 'package:my_app/features/auth/models/auth_session_result.dart';
import 'package:my_app/features/auth/state/account_block.dart';
import 'package:my_app/features/auth/state/auth_session.dart';

/// Being told why the app has stopped.
///
/// An account can be switched off from the admin panel -- a payment that has
/// not cleared, most often -- and the reason is written for that shop by the
/// person switching them off. Everything here is about that reason arriving:
/// an app that simply stops working sends somebody to the phone angry and
/// with nothing to go on, which is the failure this replaces.
void main() {
  setUp(() {
    AccountBlock.instance.clear();
    AuthSession.clear();
    AuthHttpClient.onAccountBlocked = AccountBlock.instance.raise;
  });
  tearDown(() {
    AccountBlock.instance.clear();
    AuthSession.clear();
    AuthHttpClient.onAccountBlocked = null;
  });

  void signIn() {
    AuthSession.apply(
      AuthSessionResult(
        user: const AuthUser(id: 'u1', fullName: 'A', email: 'a@b.co'),
        token: 'session-token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      ),
    );
  }

  http.Response blockedBody(String message) {
    return http.Response(
      jsonEncode(<String, Object?>{
        'ok': false,
        'error': message,
        'code': 'account_blocked',
        'blocked': true,
      }),
      403,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }

  group('an authenticated request', () {
    test('raises the owner’s own message, word for word', () async {
      signIn();
      const String written =
          'Your payment for August has not cleared. Call 0300-1234567.';
      final AuthHttpClient client = AuthHttpClient(
        MockClient((http.Request request) async => blockedBody(written)),
      );

      await client.get(Uri.parse('https://api.example.invalid/api/projects'));

      expect(AccountBlock.instance.isBlocked, isTrue);
      expect(AccountBlock.instance.message, written);
    });

    test('still hands the caller an intact body', () async {
      // The 403 is buffered to be read. If that consumed the stream the caller
      // would get an empty body and its own error handling would break.
      signIn();
      final AuthHttpClient client = AuthHttpClient(
        MockClient((http.Request request) async => blockedBody('Paused.')),
      );

      final http.Response response = await client.get(
        Uri.parse('https://api.example.invalid/api/projects'),
      );

      expect(response.statusCode, 403);
      expect(jsonDecode(response.body)['code'], 'account_blocked');
    });

    test('a 403 that is not ours blocks nobody', () async {
      signIn();
      final AuthHttpClient client = AuthHttpClient(
        MockClient(
          (http.Request request) async => http.Response('Forbidden', 403),
        ),
      );

      final http.Response response = await client.get(
        Uri.parse('https://api.example.invalid/api/projects'),
      );

      expect(AccountBlock.instance.isBlocked, isFalse);
      expect(response.body, 'Forbidden', reason: 'body still reaches the caller');
    });

    test('repeated refusals do not keep re-raising the same notice', () async {
      signIn();
      int notifications = 0;
      void count() => notifications++;
      AccountBlock.instance.addListener(count);
      addTearDown(() => AccountBlock.instance.removeListener(count));

      final AuthHttpClient client = AuthHttpClient(
        MockClient((http.Request request) async => blockedBody('Paused.')),
      );
      // Every screen in the app can be making requests at once.
      for (int i = 0; i < 5; i++) {
        await client.get(Uri.parse('https://api.example.invalid/api/projects'));
      }

      expect(notifications, 1);
    });
  });

  group('signing in', () {
    test('carries the reason, not a generic refusal', () async {
      const String written = 'Account paused pending payment.';
      final AuthApiClient api = AuthApiClient(
        baseUrl: 'https://api.example.invalid',
        httpClient: MockClient(
          (http.Request request) async => blockedBody(written),
        ),
      );

      await expectLater(
        api.login(email: 'a@b.co', password: 'x'),
        throwsA(
          isA<AuthApiException>()
              .having((AuthApiException e) => e.isAccountBlocked, 'blocked', isTrue)
              .having((AuthApiException e) => e.message, 'message', written),
        ),
      );
    });

    test('an ordinary rejection is not mistaken for a block', () async {
      final AuthApiClient api = AuthApiClient(
        baseUrl: 'https://api.example.invalid',
        httpClient: MockClient(
          (http.Request request) async => http.Response(
            jsonEncode(<String, Object?>{'error': 'invalid email or password'}),
            401,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        api.login(email: 'a@b.co', password: 'x'),
        throwsA(
          isA<AuthApiException>().having(
            (AuthApiException e) => e.isAccountBlocked,
            'blocked',
            isFalse,
          ),
        ),
      );
    });
  });

  group('the notice itself', () {
    test('clears when the account is switched back on', () {
      AccountBlock.instance.raise('Paused.');
      expect(AccountBlock.instance.isBlocked, isTrue);
      AccountBlock.instance.clear();
      expect(AccountBlock.instance.isBlocked, isFalse);
      expect(AccountBlock.instance.message, isNull);
    });

    test('an empty message is not a block', () {
      // A refusal with nothing written on it would show a blank screen, which
      // says less than the app simply not working.
      AccountBlock.instance.raise('   ');
      expect(AccountBlock.instance.isBlocked, isFalse);
    });

    test('a new message replaces the old one', () {
      AccountBlock.instance.raise('First reason.');
      AccountBlock.instance.raise('Second reason, edited from the panel.');
      expect(AccountBlock.instance.message, 'Second reason, edited from the panel.');
    });
  });
}
