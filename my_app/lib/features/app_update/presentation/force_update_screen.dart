import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../app_update_service.dart';

/// Full-screen, non-dismissible "update required" gate shown when the installed
/// direct build is below the minimum supported version. The user cannot reach
/// the app until they update.
class ForceUpdateScreen extends StatelessWidget {
  final AppUpdateStatus status;
  final AppUpdateService service;

  const ForceUpdateScreen({
    super.key,
    required this.status,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    // PopScope with canPop:false blocks the back button so the gate can't be
    // bypassed.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.pageGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppTheme.royalBlue.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        size: 48,
                        color: AppTheme.royalBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Update Required',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      status.message.isNotEmpty
                          ? status.message
                          : 'A new version of Quick AL is required to continue.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    if (status.latestVersionName.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Latest version: ${status.latestVersionName}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    UpdateActionArea(
                      apkUrl: status.apkUrl,
                      storeUrl: status.storeUrl,
                      service: service,
                      idleLabel: 'Update Now',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dismissible "update available" dialog for optional updates. The download now
/// runs *inside* the dialog with a live progress bar, so tapping Update no
/// longer just closes the dialog and appears to do nothing.
Future<void> showOptionalUpdateDialog(
  BuildContext context, {
  required AppUpdateStatus status,
  required AppUpdateService service,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        icon: const Icon(
          Icons.system_update_rounded,
          color: AppTheme.royalBlue,
          size: 32,
        ),
        title: const Text('Update available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              status.message.isNotEmpty
                  ? status.message
                  : 'A newer version of Quick AL is available.'
                        '${status.latestVersionName.isNotEmpty ? ' (${status.latestVersionName})' : ''}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            UpdateActionArea(
              apkUrl: status.apkUrl,
              storeUrl: status.storeUrl,
              service: service,
              idleLabel: 'Update',
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
        ],
      );
    },
  );
}

/// The download/install button with its live states, shared by the forced gate
/// and the optional dialog. It always shows the user what is happening:
/// a progress bar while the APK downloads, a clear hint + Retry if the install
/// permission is missing or something fails, and "opening installer" once the
/// system installer is handed the file.
class UpdateActionArea extends StatefulWidget {
  final String apkUrl;
  final AppUpdateService service;
  final String idleLabel;

  /// Set on the Play build: updating means opening the store listing, not
  /// downloading an APK over a Play install.
  final String storeUrl;

  const UpdateActionArea({
    super.key,
    required this.apkUrl,
    required this.service,
    this.idleLabel = 'Update Now',
    this.storeUrl = '',
  });

  bool get updatesViaStore => storeUrl.isNotEmpty;

  @override
  State<UpdateActionArea> createState() => _UpdateActionAreaState();
}

enum _UpdatePhase { idle, downloading, installing, permission, error }

class _UpdateActionAreaState extends State<UpdateActionArea> {
  _UpdatePhase _phase = _UpdatePhase.idle;
  int _percent = 0;
  String? _message;

  Future<void> _updateViaPlay() async {
    setState(() {
      _phase = _UpdatePhase.installing;
      _message = 'Play se update liya ja raha hai…';
    });
    final PlayUpdateOutcome outcome = await widget.service.updateViaPlay(
      widget.storeUrl,
    );
    if (!mounted) return;
    setState(() {
      switch (outcome) {
        case PlayUpdateOutcome.updated:
          // Play restarts the app itself; this is only briefly on screen.
          _phase = _UpdatePhase.installing;
          _message = 'Update ho gaya. App dobara khul rahi hai…';
        case PlayUpdateOutcome.cancelled:
          _phase = _UpdatePhase.idle;
          _message = 'Update roka gaya. Jab chahein dobara koshish karein.';
        case PlayUpdateOutcome.storeOpened:
          _phase = _UpdatePhase.installing;
          _message =
              'Play Store khul raha hai. Wahan "Update" dabayein — uske baad '
              'app dobara kholein.';
        case PlayUpdateOutcome.failed:
          _phase = _UpdatePhase.error;
          _message =
              'Update shuru nahi ho saka. Play Store khud kholein aur '
              '"Quick AL" search kar ke update karein.';
      }
    });
  }

  Future<void> _run() async {
    if (widget.updatesViaStore) {
      await _updateViaPlay();
      return;
    }
    setState(() {
      _phase = _UpdatePhase.downloading;
      _percent = 0;
      _message = null;
    });
    try {
      final String outcome = await widget.service.downloadAndInstall(
        widget.apkUrl,
        onProgress: (int percent) {
          if (!mounted) return;
          setState(() {
            _phase = _UpdatePhase.downloading;
            _percent = percent;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        if (outcome == 'permission_required') {
          _phase = _UpdatePhase.permission;
          _message =
              'Allow "Install unknown apps" for Quick AL in the screen that '
              'just opened, then come back and tap Retry.';
        } else if (outcome == 'install_started') {
          _phase = _UpdatePhase.installing;
          _message =
              'Opening the installer… follow the on-screen steps to finish. '
              'If nothing appears, tap Retry.';
        } else {
          _phase = _UpdatePhase.error;
          _message = 'Update could not start. Please tap Retry.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.error;
        _message = 'Download failed. Check your internet and tap Retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool downloading = _phase == _UpdatePhase.downloading;
    final bool showRetry =
        _phase == _UpdatePhase.permission ||
        _phase == _UpdatePhase.error ||
        _phase == _UpdatePhase.installing;

    final String label = downloading
        ? 'Downloading $_percent%'
        : showRetry
        ? (widget.updatesViaStore ? 'Dobara koshish karein' : 'Retry')
        : widget.updatesViaStore
        ? 'Update karein'
        : widget.idleLabel;

    final Color messageColor = _phase == _UpdatePhase.error
        ? AppTheme.danger
        : AppTheme.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (downloading) ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _percent > 0 ? _percent / 100 : null,
              minHeight: 8,
              backgroundColor: AppTheme.royalBlue.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: downloading ? null : _run,
            icon: downloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    widget.updatesViaStore
                        ? Icons.shop_rounded
                        : showRetry
                        ? Icons.refresh_rounded
                        : Icons.download_rounded,
                  ),
            label: Text(label),
          ),
        ),
        if (_message != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _message!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: messageColor),
          ),
        ],
      ],
    );
  }
}
