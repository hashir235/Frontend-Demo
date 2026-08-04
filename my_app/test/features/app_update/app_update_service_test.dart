import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/app_update/app_update_service.dart';

/// The Play build used to skip the version check entirely, so a Play Store
/// user was never told a new version existed -- Google's auto-update is off
/// for plenty of people, and nothing else filled the gap.
///
/// These tests are written against the wire contract rather than the build
/// flavour, because the flavour is a compile-time dart-define that a test
/// cannot change.
void main() {
  http.Client clientReturning(Map<String, Object?> body, {int status = 200}) {
    return MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(body),
        status,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
  }

  test('a store url means "open the Play Store", not "download an APK"', () {
    const AppUpdateStatus status = AppUpdateStatus(
      requirement: AppUpdateRequirement.optional,
      latestVersionName: '1.8.4',
      apkUrl: '',
      message: 'New version',
      storeUrl: 'https://play.google.com/store/apps/details?id=com.quickal.app',
    );

    expect(status.updatesViaStore, isTrue);
  });

  test('the website build keeps downloading its own APK', () {
    const AppUpdateStatus status = AppUpdateStatus(
      requirement: AppUpdateRequirement.optional,
      latestVersionName: '1.8.4',
      apkUrl: 'https://quickalapp.com/downloads/quickal-direct.apk',
      message: 'New version',
    );

    expect(status.updatesViaStore, isFalse);
    expect(status.apkUrl, isNotEmpty);
  });

  test('nothing to point at means no prompt at all', () async {
    // Neither an APK nor a store listing -- nagging the user here would leave
    // them with no way to act on it.
    final AppUpdateService service = AppUpdateService(
      httpClient: clientReturning(<String, Object?>{
        'latestVersionCode': 99,
        'latestVersionName': '9.9.9',
        'minSupportedVersionCode': 1,
        'apkUrl': '',
        'storeUrl': '',
        'updateMessage': 'Update',
      }),
      baseUrl: 'https://example.invalid',
    );

    final AppUpdateStatus status = await service.check();
    expect(status.requirement, AppUpdateRequirement.none);
  });

  test('a check failure never blocks the user', () async {
    final AppUpdateService service = AppUpdateService(
      httpClient: MockClient((http.Request _) async => http.Response('', 500)),
      baseUrl: 'https://example.invalid',
    );

    final AppUpdateStatus status = await service.check();
    expect(status.requirement, AppUpdateRequirement.none);
  });

  test('the check tells the backend which channel is asking', () async {
    // Play and website releases are on separate clocks; the backend answers
    // with the numbers for whichever channel asked, so the header has to be
    // there or Play users get told about a build the store does not have yet.
    String? sentChannel;
    final AppUpdateService service = AppUpdateService(
      httpClient: MockClient((http.Request request) async {
        sentChannel = request.headers['x-quickal-channel'];
        return http.Response(
          jsonEncode(<String, Object?>{
            'latestVersionCode': 1,
            'minSupportedVersionCode': 1,
            'apkUrl': '',
            'storeUrl': '',
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
      baseUrl: 'https://example.invalid',
    );

    await service.check();
    expect(sentChannel, isNotNull);
    expect(sentChannel, isNotEmpty);
  });
}
