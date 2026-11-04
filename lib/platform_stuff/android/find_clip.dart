import 'package:flutter/services.dart';

/// Loud repeating beep on the media output, to find a lost clip
///
/// Implemented in android/.../FindClipTone.kt: media audio goes to the
/// connected Bluetooth output, so only the clip that is still connected beeps.
/// Media volume is raised to max while beeping and restored on [stop].
abstract final class FindClip {
  static const channel = MethodChannel('freeclipbuddy/find');

  /// Throws [PlatformException] if the tone can't be played
  static Future<void> start() => channel.invokeMethod('start');

  static Future<void> stop() => channel.invokeMethod('stop');
}
