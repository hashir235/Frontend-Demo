import 'package:flutter/material.dart';

import '../models/ar_measurement_result.dart';
import '../models/inch_sutar.dart';
import '../services/ar_measurement_service.dart';
import 'ar_result_sheet.dart';

/// Orchestrates a full AR-measurement flow:
///   1. Check ARCore availability (showing helpful errors if unsupported).
///   2. Launch the native AR activity.
///   3. Show the result-confirmation sheet.
///
/// Returns the confirmed (width, height) pair in inch+sutar, or null if the
/// user cancelled or AR was unavailable.
class ArMeasurementLauncher {
  final ArMeasurementService _service;

  ArMeasurementLauncher({ArMeasurementService? service})
      : _service = service ?? const ArMeasurementService();

  Future<({InchSutar width, InchSutar height})?> launch(
    BuildContext context,
  ) async {
    final ArAvailability availability = await _service.checkAvailability();
    if (!context.mounted) return null;

    switch (availability) {
      case ArAvailability.supported:
        break;
      case ArAvailability.checking:
        await _showInfo(
          context,
          title: 'AR is starting up',
          message:
              'ARCore is verifying support. Please wait a few seconds and try again.',
        );
        return null;
      case ArAvailability.notInstalled:
        await _showInfo(
          context,
          title: 'ARCore not installed',
          message:
              'Google Play Services for AR is needed. Tap Continue to install '
              'it, then try AR measurement again.',
          actionLabel: 'Continue',
        );
        // Tapping Save Width inside the activity will request install, so we
        // try launching anyway — it surfaces the Play install dialog.
        break;
      case ArAvailability.deviceNotSupported:
        await _showInfo(
          context,
          title: 'AR not supported on this device',
          message:
              'This phone does not support ARCore. Please enter the window '
              'size manually.',
        );
        return null;
      case ArAvailability.unknown:
        await _showInfo(
          context,
          title: 'AR check failed',
          message:
              'We could not verify AR support. Try again or enter the size '
              'manually.',
        );
        return null;
    }

    if (!context.mounted) return null;
    final ArMeasurementResult? result = await _service.startMeasurement();
    if (result == null || !context.mounted) return null;

    return ArResultSheet.show(context, result);
  }

  Future<void> _showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String actionLabel = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }
}
