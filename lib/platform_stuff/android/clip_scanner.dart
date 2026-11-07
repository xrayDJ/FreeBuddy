import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../headphones/huawei/ble_finder.dart';

/// Bluetooth LE scan, implemented in android/.../ClipScanner.kt
///
/// Scans only while [scan] is listened to.
abstract final class ClipScanner {
  static const events = EventChannel('freeclipbuddy/scan');
  static const info = MethodChannel('freeclipbuddy/scan_info');

  static Stream<BleSighting> scan() => events.receiveBroadcastStream().map(
        (e) => BleSighting.fromMap(e as Map<Object?, Object?>, DateTime.now()),
      );

  /// Classic addresses of paired FreeClip 2, to spot your own clips
  static Future<List<String>> bondedClipAddresses() async =>
      (await info.invokeListMethod<String>('bondedClipAddresses')) ?? [];

  /// Bluetooth scan permission, plus location (Android needs it to show
  /// some advertisements, and before Android 12 for any scan at all)
  static Future<bool> requestPermissions() async {
    final r = await [
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    return r.values.every((s) => s.isGranted || s.isLimited);
  }

  /// With location services off, many phones return no scan results at all,
  /// silently
  static Future<bool> locationServiceOn() async =>
      (await Permission.locationWhenInUse.serviceStatus).isEnabled;
}
