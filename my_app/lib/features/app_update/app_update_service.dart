import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/api_config.dart';

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

  const AppUpdateStatus({
    required this.requirement,
    required this.latestVersionName,
    required this.apkUrl,
    required this.message,
  });

  static const AppUpdateStatus none = AppUpdateStatus(
    requirement: AppUpdateRequirement.none,
    latestVersionName: '',
    apkUrl: '',
    message: '',
  );
}

/// Checks the backend version policy and (for the direct/website build only)
/// decides whether an update is optional or forced, and triggers the native
/// download + install.
///
/// The Play build never calls this — Google Play manages its own updates.
class AppUpdateService {
  static const MethodChannel _channel =
      MethodChannel('quick_al/app_update');

  final http.Client _httpClient;
  final Uri _versionUri;

  AppUpdateService({http.Client? httpClient, String? baseUrl})
      : _httpClient = httpClient ?? http.Client(),
        _versionUri = Uri.parse(
          '${baseUrl ?? ApiConfig.baseUrl}/api/app/version',
        );

  /// Fetches the policy and compares it with the installed build number.
  /// Returns [AppUpdateStatus.none] for the Play build, on any error, or when
  /// up to date — so a check failure never blocks the user by mistake.
  Future<AppUpdateStatus> check() async {
    // Only the direct/website build self-updates.
    if (!ApiConfig.isDirectWebsiteBuild) {
      return AppUpdateStatus.none;
    }

    try {
      final http.Response response = await _httpClient
          .get(_versionUri)
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

      final PackageInfo info = await PackageInfo.fromPlatform();
      final int installed = int.tryParse(info.buildNumber) ?? 0;

      // No usable APK url → don't nag the user.
      if (apkUrl.isEmpty) {
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
  Future<String> downloadAndInstall(String apkUrl) async {
    final String? outcome = await _channel.invokeMethod<String>(
      'downloadAndInstallApk',
      <String, Object?>{'url': apkUrl},
    );
    return outcome ?? 'unknown';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
