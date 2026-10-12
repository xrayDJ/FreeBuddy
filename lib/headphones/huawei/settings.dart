enum DoubleTap {
  nothing,
  voiceAssistant,
  playPause,
  next,
  previous;
}

/// Sound quality preference (connectivity vs quality codec priority)
enum SoundQuality { connectivity, quality }

/// Long-press action on FreeClip 2 (no ANC on this model)
enum LongPress { nothing, voiceAssistant, volumeUp, volumeDown }

/// Settings for HUAWEI FreeClip 2 (open-ear clip). No ANC on this model.
/// Command IDs ported from OpenFreebuds' OfbDriverHuaweiFreeClip2.
class HuaweiFreeClip2Settings {
  final DoubleTap? doubleTapLeft;
  final DoubleTap? doubleTapRight;
  final DoubleTap? tripleTapLeft;
  final DoubleTap? tripleTapRight;
  final LongPress? longPressLeft;
  final LongPress? longPressRight;

  /// Swipe on the bud changes volume (true) or does nothing (false)
  final bool? swipeVolume;
  final bool? autoPause;
  final bool? lowLatency;
  final bool? dualConnect;
  final SoundQuality? soundQuality;

  const HuaweiFreeClip2Settings({
    this.doubleTapLeft,
    this.doubleTapRight,
    this.tripleTapLeft,
    this.tripleTapRight,
    this.longPressLeft,
    this.longPressRight,
    this.swipeVolume,
    this.autoPause,
    this.lowLatency,
    this.dualConnect,
    this.soundQuality,
  });

  HuaweiFreeClip2Settings copyWith({
    DoubleTap? doubleTapLeft,
    DoubleTap? doubleTapRight,
    DoubleTap? tripleTapLeft,
    DoubleTap? tripleTapRight,
    LongPress? longPressLeft,
    LongPress? longPressRight,
    bool? swipeVolume,
    bool? autoPause,
    bool? lowLatency,
    bool? dualConnect,
    SoundQuality? soundQuality,
  }) =>
      HuaweiFreeClip2Settings(
        doubleTapLeft: doubleTapLeft ?? this.doubleTapLeft,
        doubleTapRight: doubleTapRight ?? this.doubleTapRight,
        tripleTapLeft: tripleTapLeft ?? this.tripleTapLeft,
        tripleTapRight: tripleTapRight ?? this.tripleTapRight,
        longPressLeft: longPressLeft ?? this.longPressLeft,
        longPressRight: longPressRight ?? this.longPressRight,
        swipeVolume: swipeVolume ?? this.swipeVolume,
        autoPause: autoPause ?? this.autoPause,
        lowLatency: lowLatency ?? this.lowLatency,
        dualConnect: dualConnect ?? this.dualConnect,
        soundQuality: soundQuality ?? this.soundQuality,
      );
}
