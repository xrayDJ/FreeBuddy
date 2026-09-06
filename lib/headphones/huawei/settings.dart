import '../framework/anc.dart';

class HuaweiFreeBuds4iSettings {
  // hey hey hay, not only settings are gonna be duplicate spaghetti shithole,
  // but all the fields are gonna be nullable too!
  final DoubleTap? doubleTapLeft;
  final DoubleTap? doubleTapRight;
  final Hold? holdBoth;
  final Set<AncMode>? holdBothToggledAncModes;

  final bool? autoPause;

  const HuaweiFreeBuds4iSettings({
    this.doubleTapLeft,
    this.doubleTapRight,
    this.holdBoth,
    this.holdBothToggledAncModes,
    this.autoPause,
  });

  // don't want to use codegen *yet*
  HuaweiFreeBuds4iSettings copyWith({
    DoubleTap? doubleTapLeft,
    DoubleTap? doubleTapRight,
    Hold? holdBoth,
    Set<AncMode>? holdBothToggledAncModes,
    bool? autoPause,
  }) =>
      HuaweiFreeBuds4iSettings(
        doubleTapLeft: doubleTapLeft ?? this.doubleTapLeft,
        doubleTapRight: doubleTapRight ?? this.doubleTapRight,
        holdBoth: holdBoth ?? this.holdBoth,
        holdBothToggledAncModes:
            holdBothToggledAncModes ?? this.holdBothToggledAncModes,
        autoPause: autoPause ?? this.autoPause,
      );
}

class HuaweiFreeBuds3iSettings {
  // hey hey hay, not only settings are gonna be duplicate spaghetti shithole,
  // but all the fields are gonna be nullable too!
  final DoubleTap? doubleTapLeft;
  final DoubleTap? doubleTapRight;

  // those are luckily same as 4i
  final Hold? holdBoth;
  final Set<AncMode>? holdBothToggledAncModes;

  // They do have auto-pause... but it's not settable from app 🤷
  // but we may find it some day! That's why I'm commenting it out
  // final bool? autoPause;

  const HuaweiFreeBuds3iSettings({
    this.doubleTapLeft,
    this.doubleTapRight,
    this.holdBoth,
    this.holdBothToggledAncModes,
    // this.autoPause,
  });

  // don't want to use codegen *yet*
  HuaweiFreeBuds3iSettings copyWith({
    DoubleTap? doubleTapLeft,
    DoubleTap? doubleTapRight,
    Hold? holdBoth,
    Set<AncMode>? holdBothToggledAncModes,
    // bool? autoPause,
  }) =>
      HuaweiFreeBuds3iSettings(
        doubleTapLeft: doubleTapLeft ?? this.doubleTapLeft,
        doubleTapRight: doubleTapRight ?? this.doubleTapRight,
        holdBoth: holdBoth ?? this.holdBoth,
        holdBothToggledAncModes:
            holdBothToggledAncModes ?? this.holdBothToggledAncModes,
        // autoPause: autoPause ?? this.autoPause,
      );
}

// i don't have idea how to public/privatise those and how to name them
// let's assume that any screen/logic that uses them at all is already
// model-specific so generic names are okay

enum DoubleTap {
  nothing,
  voiceAssistant,
  playPause,
  next,
  previous;
}

enum Hold {
  nothing,
  cycleAnc;
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
