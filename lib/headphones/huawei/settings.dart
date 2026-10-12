/// Gesture action codes, exactly as the FreeClip 2 sends them (signed byte)
///
/// The device can report codes we don't know - keep them as plain [int]s so
/// the UI can still show them instead of pretending nothing is set.
///
/// Codes from OpenFreebuds (GPL-3.0, melianmiko/OpenFreebuds)
abstract final class GestureAction {
  static const off = -1;
  static const voiceAssistant = 0;
  static const playPause = 1;
  static const next = 2;
  static const previous = 7;
  static const volumeUp = 18;
  static const volumeDown = 19;

  /// Shown for taps when the device doesn't list the allowed actions
  static const tapFallback = [off, playPause, next, previous, voiceAssistant];

  /// Shown for long press when the device doesn't list the allowed actions
  static const longPressFallback = [off, voiceAssistant, volumeUp, volumeDown];
}

/// Sound quality preference (connectivity vs quality codec priority)
enum SoundQuality { connectivity, quality }

/// Settings for HUAWEI FreeClip 2 (open-ear clip). No ANC on this model.
///
/// All fields are nullable - null means "the device didn't tell us (yet)".
/// Gesture fields are [GestureAction] codes. `*Options` are the actions the
/// device itself says a gesture accepts (param 3 of the read reply).
class HuaweiFreeClip2Settings {
  final int? doubleTapLeft;
  final int? doubleTapRight;
  final List<int>? doubleTapOptions;
  final int? tripleTapLeft;
  final int? tripleTapRight;
  final List<int>? tripleTapOptions;

  /// On FreeClip 2 long press may be a single setting for both clips - then
  /// only [longPressLeft] is reported and [longPressRight] stays null
  final int? longPressLeft;
  final int? longPressRight;
  final List<int>? longPressOptions;

  /// Swipe on the bud changes volume (true) or does nothing (false)
  final bool? swipeVolume;
  final bool? autoPause;
  final bool? lowLatency;
  final bool? dualConnect;
  final SoundQuality? soundQuality;

  const HuaweiFreeClip2Settings({
    this.doubleTapLeft,
    this.doubleTapRight,
    this.doubleTapOptions,
    this.tripleTapLeft,
    this.tripleTapRight,
    this.tripleTapOptions,
    this.longPressLeft,
    this.longPressRight,
    this.longPressOptions,
    this.swipeVolume,
    this.autoPause,
    this.lowLatency,
    this.dualConnect,
    this.soundQuality,
  });

  HuaweiFreeClip2Settings copyWith({
    int? doubleTapLeft,
    int? doubleTapRight,
    List<int>? doubleTapOptions,
    int? tripleTapLeft,
    int? tripleTapRight,
    List<int>? tripleTapOptions,
    int? longPressLeft,
    int? longPressRight,
    List<int>? longPressOptions,
    bool? swipeVolume,
    bool? autoPause,
    bool? lowLatency,
    bool? dualConnect,
    SoundQuality? soundQuality,
  }) =>
      HuaweiFreeClip2Settings(
        doubleTapLeft: doubleTapLeft ?? this.doubleTapLeft,
        doubleTapRight: doubleTapRight ?? this.doubleTapRight,
        doubleTapOptions: doubleTapOptions ?? this.doubleTapOptions,
        tripleTapLeft: tripleTapLeft ?? this.tripleTapLeft,
        tripleTapRight: tripleTapRight ?? this.tripleTapRight,
        tripleTapOptions: tripleTapOptions ?? this.tripleTapOptions,
        longPressLeft: longPressLeft ?? this.longPressLeft,
        longPressRight: longPressRight ?? this.longPressRight,
        longPressOptions: longPressOptions ?? this.longPressOptions,
        swipeVolume: swipeVolume ?? this.swipeVolume,
        autoPause: autoPause ?? this.autoPause,
        lowLatency: lowLatency ?? this.lowLatency,
        dualConnect: dualConnect ?? this.dualConnect,
        soundQuality: soundQuality ?? this.soundQuality,
      );
}
