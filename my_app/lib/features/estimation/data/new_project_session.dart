import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/auth_http_client.dart';
import '../../settings/state/app_settings.dart';
import '../state/estimate_session_store.dart';
import 'project_repository.dart';

/// What a shop is told when their new project could not be saved yet.
const String newProjectNotSavedMessage =
    'This project could not be saved to your account yet — check your '
    'internet. Your windows are kept, and it is saved as soon as it can be.';

/// A session for a brand-new project, ready to use this instant.
///
/// Pressing Create used to wait on two trips to the server, one after the
/// other -- a reset of the old single-session files, then the new project --
/// before the window library would open. Over a phone connection, to a
/// database that may first have to wake up, that was seconds of a screen
/// doing nothing. Neither is needed to pick a window, so now:
///
/// * the session exists straight away and the library opens on it;
/// * the project is written to the server behind it, and everything that
///   needs the project waits for it ([EstimateSessionStore.ensureProject]);
/// * the reset still runs, but as the housekeeping it is -- it tidies files
///   the new project never reads, and it no longer holds anything up.
///
/// If the project cannot be written (no signal), the shop is told, their
/// windows are kept, and the next save tries again.
EstimateSessionStore startNewProjectSession({
  required EstimateFlow flow,
  required String projectName,
  required String projectLocation,
  required ScaffoldMessengerState messenger,
  ProjectRepository? repository,
  Future<void> Function()? resetLegacySession,
}) {
  unawaited((resetLegacySession ?? _resetLegacySession)());

  final ProjectRepository projects = repository ?? ProjectRepository();
  final EstimateSessionStore session = EstimateSessionStore(
    projectName: projectName,
    projectLocation: projectLocation,
    flow: flow,
    numberingMode: AppSettings.instance.numberingMode,
  );
  session.startCreatingProject(() async {
    final project = await projects.createProject(
      flow: flow,
      projectName: projectName,
      projectLocation: projectLocation,
    );
    return project.id;
  });

  unawaited(
    session.ensureProject().then((String? id) {
      if (id == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text(newProjectNotSavedMessage)),
        );
      }
    }),
  );
  return session;
}

/// Clears the old single-session scratch files on the server. Only requests
/// that carry no project read them, so a failure here costs nothing and is
/// not reported.
Future<void> _resetLegacySession() async {
  try {
    await AuthHttpClient()
        .post(
          ApiConfig.buildUri('/api/estimation/reset-session'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(const <String, Object?>{}),
        )
        .timeout(const Duration(seconds: 5));
  } on Object {
    // Housekeeping only.
  }
}
