import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/auth/data/auth_api_client.dart';

/// What the app says when the phone cannot reach us.
///
/// A user sent in a screenshot reading "Unable to reach authentication
/// service." while the server was up, answering every other request that
/// minute, with no error in any log. The message was wrong twice over: it
/// blamed a service that was healthy, and it pointed the user at something
/// they cannot do anything about.
///
/// The failure is a dead socket -- no DNS, no route, no TLS, or no answer in
/// time -- and on a phone that is nearly always the phone's own connection.
/// These tests hold the app to saying so, and to giving up rather than
/// spinning forever when the network stalls halfway.
void main() {
  AuthApiClient clientThat(
    Future<http.Response> Function(http.Request request) handle,
  ) {
    return AuthApiClient(
      httpClient: MockClient(handle),
      baseUrl: 'https://api.example.invalid',
    );
  }

  test('a dead network blames the connection, not the server', () async {
    // Exactly what a phone with no signal throws.
    final AuthApiClient api = clientThat(
      (http.Request request) async =>
          throw const SocketException('Failed host lookup: api.quickalapp.com'),
    );

    await expectLater(
      api.signInWithGoogle(idToken: 'a.b.c'),
      throwsA(
        isA<AuthApiException>().having(
          (AuthApiException e) => e.message,
          'message',
          allOf(
            contains('Could not reach Quick AL'),
            contains('internet connection'),
            // The old wording sent people looking for an outage that was not
            // happening. It must not come back.
            isNot(contains('authentication service')),
          ),
        ),
      ),
    );
  });

  test('every way in says the same thing when the socket is dead', () async {
    AuthApiClient dead() => clientThat(
      (http.Request request) async => throw const SocketException('no route'),
    );

    final List<Future<Object?>> attempts = <Future<Object?>>[
      dead().login(email: 'a@b.co', password: 'x'),
      dead().register(fullName: 'A', email: 'a@b.co', password: 'x'),
      dead().signInWithGoogle(idToken: 'a.b.c'),
      dead().requestPasswordReset(email: 'a@b.co'),
    ];

    for (final Future<Object?> attempt in attempts) {
      await expectLater(
        attempt,
        throwsA(
          isA<AuthApiException>().having(
            (AuthApiException e) => e.message,
            'message',
            contains('Could not reach Quick AL'),
          ),
        ),
      );
    }
  });

  test('a server that never answers is given up on, not waited on forever', () {
    fakeAsync((FakeAsync async) {
      // A stalled mobile connection: the request goes out and nothing ever
      // comes back. Before the timeout this hung with the spinner turning.
      final AuthApiClient api = clientThat(
        (http.Request request) => Completer<http.Response>().future,
      );

      Object? thrown;
      api
          .login(email: 'a@b.co', password: 'x')
          .then<void>((_) {}, onError: (Object error) => thrown = error);

      async.elapse(const Duration(seconds: 19));
      expect(
        thrown,
        isNull,
        reason: 'a slow network must be given time to answer',
      );

      async.elapse(const Duration(seconds: 2));
      expect(thrown, isA<AuthApiException>());
      expect(
        (thrown! as AuthApiException).message,
        contains('internet connection'),
      );
    });
  });

  test('a server that does answer keeps its own message', () async {
    // The point of the change is to separate "we never got there" from "the
    // server said no". A rejected token is the second, and must read as such.
    final AuthApiClient api = clientThat(
      (http.Request request) async => http.Response(
        jsonEncode(<String, Object?>{'error': 'Google token was rejected.'}),
        401,
        headers: <String, String>{'content-type': 'application/json'},
      ),
    );

    await expectLater(
      api.signInWithGoogle(idToken: 'a.b.c'),
      throwsA(
        isA<AuthApiException>().having(
          (AuthApiException e) => e.message,
          'message',
          allOf(
            contains('Google token was rejected'),
            isNot(contains('Could not reach')),
          ),
        ),
      ),
    );
  });
}
