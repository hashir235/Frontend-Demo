import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/auth/models/auth_session_result.dart';
import 'package:my_app/features/auth/models/auth_user.dart';
import 'package:my_app/features/auth/state/auth_session.dart';
import 'package:my_app/features/auth/data/auth_api_client.dart';

/// Account deletion was broken for every real user of this app.
///
/// Sign-in is by Google, so those accounts carry no password -- but the only
/// way to delete one was a web form that asked for a password and then told
/// people theirs was wrong. Google Play rejected a release over it, and they
/// were right to.
///
/// These tests hold the working route in place: the session proves who is
/// asking, and nothing is claimed to be deleted unless the server said so.
void main() {
  setUp(() => AuthSession.clear());
  tearDown(() => AuthSession.clear());

  http.Client client({
    required int status,
    Map<String, Object?> body = const <String, Object?>{},
    void Function(http.Request request)? onRequest,
  }) {
    return MockClient((http.Request request) async {
      onRequest?.call(request);
      return http.Response(
        jsonEncode(body),
        status,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
  }

  test('deletion uses the session, and never asks for a password', () async {
    _signIn();
    late http.Request seen;

    final AuthApiClient api = AuthApiClient(
      httpClient: client(
        status: 200,
        body: <String, Object?>{'ok': true, 'deleted': true},
        onRequest: (http.Request r) => seen = r,
      ),
      baseUrl: 'https://example.invalid',
    );

    await api.deleteAccount();

    expect(seen.method, 'DELETE');
    expect(seen.url.path, '/api/account');
    expect(seen.headers['Authorization'], 'Bearer session-abc');
    // A password field here would be the old broken design coming back.
    expect(seen.body.toLowerCase(), isNot(contains('password')));
  });

  test('a signed-out caller is stopped before any request goes out', () async {
    bool called = false;
    final AuthApiClient api = AuthApiClient(
      httpClient: client(status: 200, onRequest: (_) => called = true),
      baseUrl: 'https://example.invalid',
    );

    await expectLater(api.deleteAccount(), throwsA(isA<AuthApiException>()));
    expect(called, isFalse);
  });

  test('a server refusal is surfaced, not swallowed', () async {
    // Reporting success on a failure would leave someone believing their data
    // is gone when it is still there -- the worst outcome of the three.
    _signIn();
    final AuthApiClient api = AuthApiClient(
      httpClient: client(
        status: 500,
        body: <String, Object?>{
          'ok': false,
          'error': 'account deletion failed',
        },
      ),
      baseUrl: 'https://example.invalid',
    );

    await expectLater(api.deleteAccount(), throwsA(isA<AuthApiException>()));
  });

  test('a dropped connection says nothing was deleted', () async {
    _signIn();
    final AuthApiClient api = AuthApiClient(
      httpClient: MockClient((http.Request _) async => throw const _Offline()),
      baseUrl: 'https://example.invalid',
    );

    try {
      await api.deleteAccount();
      fail('expected a failure');
    } on AuthApiException catch (error) {
      expect(error.message.toLowerCase(), contains('nothing has been deleted'));
    }
  });
}

class _Offline implements Exception {
  const _Offline();
}

/// Puts a signed-in session in place, the way the app does after Google
/// sign-in -- note there is no password anywhere in it.
void _signIn() {
  AuthSession.apply(
    const AuthSessionResult(
      user: AuthUser(
        id: 'u1',
        fullName: 'Test User',
        email: 'test@example.com',
      ),
      token: 'session-abc',
      expiresAt: null,
    ),
  );
}
