import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../app_update_service.dart';

/// Full-screen, non-dismissible "update required" gate shown when the installed
/// direct build is below the minimum supported version. The user cannot reach
/// the app until they update.
class ForceUpdateScreen extends StatefulWidget {
  final AppUpdateStatus status;
  final AppUpdateService service;

  const ForceUpdateScreen({
    super.key,
    required this.status,
    required this.service,
  });

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _busy = false;
  String? _hint;

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _hint = null;
    });
    try {
      final String outcome =
          await widget.service.downloadAndInstall(widget.status.apkUrl);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (outcome == 'permission_required') {
          _hint =
              'Please allow "Install unknown apps" for Quick AL, then tap '
              'Update again.';
        } else {
          // install_started — the system installer is now open.
          _hint = 'Follow the installer to finish updating.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hint = 'Update could not start. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope with canPop:false blocks the back button so the gate can't be
    // bypassed.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.status.message.isNotEmpty
                          ? widget.status.message
                          : 'A new version of Quick AL is required to continue.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    if (widget.status.latestVersionName.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Latest version: ${widget.status.latestVersionName}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _update,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(_busy ? 'Downloading…' : 'Update Now'),
                      ),
                    ),
                    if (_hint != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        _hint!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
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

/// Dismissible "update available" dialog for optional updates.
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
        content: Text(
          status.message.isNotEmpty
              ? status.message
              : 'A newer version of Quick AL is available.'
                  '${status.latestVersionName.isNotEmpty ? ' (${status.latestVersionName})' : ''}',
          textAlign: TextAlign.center,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await service.downloadAndInstall(status.apkUrl);
              } catch (_) {
                // Optional update — silent failure is acceptable.
              }
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Update'),
          ),
        ],
      );
    },
  );
}
