import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';

/// How a Play user's update attempt ended.
enum PlayUpdateOutcome {
  /// Play installed it in place; the app restarts itself.
  updated,

  /// The in-app flow was not available, so the store listing was opened.
  storeOpened,

  /// The user backed out of Play's own update sheet.
  cancelled,

  /// Neither the in-app flow nor the listing could be opened.
  failed,
}

/// What the app should do about its version on startup.
enum AppUpdateRequirement {
  /// Up to date — nothing to do.
  none,

  /// A newer version exists but the current one is still allowed. The user may
  /// update or skip.
  optional,

  /// The current version is below the minimum supported — the app must update
  /// before it can be used.
  forced,
}

/// The result of a version check.
class AppUpdateStatus {
  final AppUpdateRequirement requirement;
  final String latestVersionName;
  final String apkUrl;
  final String message;

  /// Play Store listing to send the user to. Empty on the website build, which
  /// downloads and installs the APK itself.
  final String storeUrl;

  const AppUpdateStatus({
    required this.requirement,
    required this.latestVersionName,
    required this.apkUrl,
    required this.message,
    this.storeUrl = '',
  });

  /// True when updating means "go to the Play Store", not "download an APK".
  bool get updatesViaStore => storeUrl.isNotEmpty;

  static const AppUpdateStatus none = AppUpdateStatus(
    requirement: AppUpdateRequirement.none,
    latestVersionName: '',
    apkUrl: '',
    message: '',
  );
}

/// Checks the backend version policy and decides whether an update is optional
/// or forced.
///
/// How the user updates depends on where their copy came from. The website
/// build downloads and installs the APK itself. The Play build cannot -- and
/// should not -- do that, so it opens the store listing instead. Play's own
/// auto-update is off for plenty of people, so without this a Play user simply
/// never learns a new version exists.
class AppUpdateService {
  static const MethodChannel _channel = MethodChannel('quick_al/app_update');

  final http.Client _httpClient;
  final Uri _versionUri;

  AppUpdateService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _versionUri = Uri.parse(
        '${baseUrl ?? ApiConfig.baseUrl}/api/app/version',
      );

  /// Fetches the policy and compares it with the installed build number.
  /// Returns [AppUpdateStatus.none] on any error, or when up to date — so a
  /// check failure never blocks the user by mistake.
  Future<AppUpdateStatus> check() async {
    try {
      // The two channels are on separate release clocks -- the website APK is
      // live on deploy, a Play build only after Google's review -- so the
      // backend answers with the numbers for whichever channel is asking.
      final http.Response response = await _httpClient
          .get(
            _versionUri,
            headers: <String, String>{
              'x-quickal-channel': ApiConfig.subscriptionChannel,
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppUpdateStatus.none;
      }
      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      final int latest = _toInt(body['latestVersionCode']);
      final int minSupported = _toInt(body['minSupportedVersionCode']);
      final String apkUrl = (body['apkUrl'] as String?)?.trim() ?? '';
      final String latestName =
          (body['latestVersionName'] as String?)?.trim() ?? '';
      final String message = (body['updateMessage'] as String?)?.trim() ?? '';
      String storeUrl = (body['storeUrl'] as String?)?.trim() ?? '';

      final PackageInfo info = await PackageInfo.fromPlatform();
      final int installed = int.tryParse(info.buildNumber) ?? 0;

      // An older backend answers without storeUrl. The Play build still needs
      // somewhere to send people, and the listing is derived from the package
      // name it is already running under.
      if (storeUrl.isEmpty && !ApiConfig.isDirectWebsiteBuild) {
        storeUrl =
            'https://play.google.com/store/apps/details?id=${info.packageName}';
      }

      // Nowhere to send the user → don't nag them.
      if (apkUrl.isEmpty && storeUrl.isEmpty) {
        return AppUpdateStatus.none;
      }

      AppUpdateRequirement requirement;
      if (installed < minSupported) {
        requirement = AppUpdateRequirement.forced;
      } else if (installed < latest) {
        requirement = AppUpdateRequirement.optional;
      } else {
        requirement = AppUpdateRequirement.none;
      }

      return AppUpdateStatus(
        requirement: requirement,
        latestVersionName: latestName,
        apkUrl: apkUrl,
        message: message,
        storeUrl: storeUrl,
      );
    } catch (_) {
      // Network/parse failure must never lock the user out.
      return AppUpdateStatus.none;
    }
  }

  /// Triggers the native download + install of the given APK url.
  ///
  /// Returns one of: `install_started`, `permission_required`, or a thrown
  /// [PlatformException] on failure. `permission_required` means the user was
  /// sent to enable "install unknown apps" and should retry afterwards.
  ///
  /// [onProgress] receives 0..100 download percentages while the (large) APK
  /// downloads, so the UI can show a live progress bar instead of appearing to
  /// hang.
  Future<String> downloadAndInstall(
    String apkUrl, {
    void Function(int percent)? onProgress,
  }) async {
    if (onProgress != null) {
      _channel.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'downloadProgress') {
          final int percent = (call.arguments as num?)?.round() ?? 0;
          onProgress(percent.clamp(0, 100));
        }
        return null;
      });
    }
    try {
      final String? outcome = await _channel.invokeMethod<String>(
        'downloadAndInstallApk',
        <String, Object?>{'url': apkUrl},
      );
      return outcome ?? 'unknown';
    } finally {
      // Stop listening so a later call (or another instance) starts clean.
      _channel.setMethodCallHandler(null);
    }
  }

  /// What happened when a Play user asked to update.
  ///
  /// [updated] means Play installed it and the app is about to restart;
  /// [storeOpened] means we could not do it in place and sent them to the
  /// listing instead; [cancelled] means they backed out of Play's own sheet.
  Future<PlayUpdateOutcome> updateViaPlay(String storeUrl) async {
    // Play's in-app flow only exists for a copy actually installed from the
    // Play Store, and only once Google has a newer build staged for this
    // user. Everything else -- a sideloaded copy, no Play services, a release
    // still in review -- lands in the catch below and gets the listing.
    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        final AppUpdateResult result =
            await InAppUpdate.performImmediateUpdate();
        switch (result) {
          case AppUpdateResult.success:
            return PlayUpdateOutcome.updated;
          case AppUpdateResult.userDeniedUpdate:
            return PlayUpdateOutcome.cancelled;
          case AppUpdateResult.inAppUpdateFailed:
            break; // fall through to the listing
        }
      }
    } catch (_) {
      // Not installed from Play, Play services missing, or nothing staged.
    }

    final bool opened = await openStore(storeUrl);
    return opened ? PlayUpdateOutcome.storeOpened : PlayUpdateOutcome.failed;
  }

  /// Opens the Play Store listing so the user can update from there.
  ///
  /// Tries the `market:` scheme first, which lands directly in the Play Store
  /// app; falls back to the https listing on devices where Play is missing or
  /// the scheme is not handled.
  Future<bool> openStore(String storeUrl) async {
    final Uri httpsUri = Uri.parse(storeUrl);
    final String? packageName = httpsUri.queryParameters['id'];
    if (packageName != null && packageName.isNotEmpty) {
      final Uri marketUri = Uri.parse('market://details?id=$packageName');
      try {
        if (await launchUrl(marketUri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {
        // No Play Store app -- fall through to the browser.
      }
    }
    try {
      return await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
