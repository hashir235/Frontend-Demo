import 'package:flutter/services.dart';

import '../models/ar_measurement_result.dart';

/// Availability of ARCore on the current device. We map the native enum
/// onto a friendly set of states.
enum ArAvailability {
  /// AR is fully supported and installed.
  supported,

  /// ARCore is still verifying — caller should re-check shortly.
  checking,

  /// ARCore APK isn't installed yet, but the device supports it.
  notInstalled,

  /// The device itself doesn't support ARCore.
  deviceNotSupported,

  /// Unknown error or non-Android platform.
  unknown,
}

ArAvailability _mapAvailability(String? raw) {
  switch (raw) {
    case 'supported':
      return ArAvailability.supported;
    case 'checking':
      return ArAvailability.checking;
    case 'not_installed':
      return ArAvailability.notInstalled;
    case 'device_not_supported':
      return ArAvailability.deviceNotSupported;
    default:
      return ArAvailability.unknown;
  }
}

/// Talks to the native AR measurement activity over a MethodChannel.
class ArMeasurementService {
  static const MethodChannel _channel =
      MethodChannel('quick_al/ar_measurement');

  const ArMeasurementService();

  Future<ArAvailability> checkAvailability() async {
    try {
      final String? raw =
          await _channel.invokeMethod<String>('checkAvailability');
      return _mapAvailability(raw);
    } on MissingPluginException {
      return ArAvailability.unknown;
    } on PlatformException {
      return ArAvailability.unknown;
    }
  }

  /// Launches the native AR activity. Returns the captured result, or `null`
  /// if the user cancelled.
  Future<ArMeasurementResult?> startMeasurement() async {
    try {
      final Map<dynamic, dynamic>? payload =
          await _channel.invokeMapMethod<dynamic, dynamic>('startMeasurement');
      if (payload == null) return null;
      return ArMeasurementResult.fromMap(payload);
    } on PlatformException {
      return null;
    }
  }
}
