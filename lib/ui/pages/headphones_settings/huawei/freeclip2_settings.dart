import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../headphones/framework/headphones_settings.dart';
import '../../../../headphones/huawei/settings.dart';
import '../../../common/list_tile_radio.dart';
import '../../../common/list_tile_switch.dart';

typedef _H = HeadphonesSettings<HuaweiFreeClip2Settings>;
typedef _S = HuaweiFreeClip2Settings;

/// All FreeClip 2 settings in one place
List<Widget> freeClip2SettingsWidgets(
  HeadphonesSettings<HuaweiFreeClip2Settings> h,
) =>
    [
      _SectionHeader((l) => l.freeClip2SectionGestures),
      _Gesture(
        h,
        title: (l) => l.pageHeadphonesSettingsDoubleTap,
        fallback: GestureAction.tapFallback,
        read: (s) => (s.doubleTapLeft, s.doubleTapRight, s.doubleTapOptions),
        write: (l, r) => _S(doubleTapLeft: l, doubleTapRight: r),
      ),
      _Gesture(
        h,
        title: (l) => l.freeClip2TripleTap,
        fallback: GestureAction.tapFallback,
        read: (s) => (s.tripleTapLeft, s.tripleTapRight, s.tripleTapOptions),
        write: (l, r) => _S(tripleTapLeft: l, tripleTapRight: r),
      ),
      _Gesture(
        h,
        title: (l) => l.pageHeadphonesSettingsHold,
        fallback: GestureAction.longPressFallback,
        read: (s) => (s.longPressLeft, s.longPressRight, s.longPressOptions),
        write: (l, r) => _S(longPressLeft: l, longPressRight: r),
      ),
      _Gesture(
        h,
        title: (l) => l.freeClip2Swipe,
        subtitle: (l) => l.freeClip2SwipeDesc,
        fallback: GestureAction.swipeFallback,
        label: _swipeLabel,
        // one setting for both clips
        read: (s) => (s.swipeAction, null, s.swipeOptions),
        write: (l, _) => _S(swipeAction: l),
        bothTitle: false,
      ),
      _Gesture(
        h,
        title: (l) => l.freeClip2DoubleTapInCall,
        fallback: GestureAction.inCallFallback,
        label: _inCallLabel,
        read: (s) => (
          s.doubleTapInCallLeft,
          s.doubleTapInCallRight,
          s.doubleTapInCallOptions,
        ),
        write: (l, r) => _S(doubleTapInCallLeft: l, doubleTapInCallRight: r),
        hideUntilKnown: true,
      ),
      _Gesture(
        h,
        title: (l) => l.freeClip2HoldInCall,
        fallback: GestureAction.inCallFallback,
        label: _inCallLabel,
        read: (s) => (
          s.longPressInCallLeft,
          s.longPressInCallRight,
          s.longPressInCallOptions,
        ),
        write: (l, r) => _S(longPressInCallLeft: l, longPressInCallRight: r),
        hideUntilKnown: true,
      ),
      _SectionHeader((l) => l.freeClip2SectionSound),
      _SoundQuality(h),
      _Toggle(
        h,
        (l) => (l.freeClip2LowLatency, l.freeClip2LowLatencyDesc),
        (s) => s.lowLatency,
        (v) => _S(lowLatency: v),
      ),
      _SectionHeader((l) => l.freeClip2SectionGeneral),
      _Toggle(
        h,
        (l) => (l.autoPause, l.autoPauseDesc),
        (s) => s.autoPause,
        (v) => _S(autoPause: v),
      ),
      _Toggle(
        h,
        (l) => (l.freeClip2DualConnect, l.freeClip2DualConnectDesc),
        (s) => s.dualConnect,
        (v) => _S(dualConnect: v),
      ),
      const SizedBox(height: 64),
    ];

/// Human name of a [GestureAction] code
///
/// Codes nobody has identified yet show up as "Unknown action (N)" - they
/// are still selectable, so they can be tried out on the clips.
String gestureActionLabel(AppLocalizations l, int code) => switch (code) {
      GestureAction.off => l.pageHeadphonesSettingsDoubleTapNone,
      GestureAction.voiceAssistant => l.pageHeadphonesSettingsDoubleTapAssist,
      GestureAction.playPause => l.pageHeadphonesSettingsDoubleTapPlayPause,
      GestureAction.next => l.pageHeadphonesSettingsDoubleTapNextSong,
      GestureAction.previous => l.pageHeadphonesSettingsDoubleTapPrevSong,
      GestureAction.volumeUp => l.freeClip2VolumeUp,
      GestureAction.volumeDown => l.freeClip2VolumeDown,
      _ => l.gestureActionUnknown(code),
    };

/// Swipe uses its own code table: 0 is volume here, not voice assistant
String _swipeLabel(AppLocalizations l, int code) => switch (code) {
      GestureAction.off => l.pageHeadphonesSettingsDoubleTapNone,
      GestureAction.swipeVolume => l.freeClip2SwipeVolume,
      _ => l.gestureActionUnknown(code),
    };

/// In-call gestures too: 0 is answer / end call
String _inCallLabel(AppLocalizations l, int code) => switch (code) {
      GestureAction.off => l.pageHeadphonesSettingsDoubleTapNone,
      GestureAction.answerCall => l.freeClip2InCallAnswer,
      _ => l.gestureActionUnknown(code),
    };

class _SectionHeader extends StatelessWidget {
  final String Function(AppLocalizations) text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text(AppLocalizations.of(context)!),
        style: t.textTheme.titleSmall!.copyWith(color: t.colorScheme.primary),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final _H h;
  final (String, String) Function(AppLocalizations) texts;
  final bool? Function(_S) read;
  final _S Function(bool) write;

  const _Toggle(this.h, this.texts, this.read, this.write);

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = texts(AppLocalizations.of(context)!);
    return StreamBuilder<bool?>(
      stream: h.settings.map(read),
      builder: (_, snap) => ListTileSwitch(
        title: Text(title),
        subtitle: Text(subtitle),
        value: snap.data ?? false,
        // disabled until the device tells us the real value
        onChanged: snap.data == null ? null : (v) => h.setSettings(write(v)),
      ),
    );
  }
}

class _SoundQuality extends StatelessWidget {
  final _H h;

  const _SoundQuality(this.h);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return StreamBuilder<SoundQuality?>(
      stream: h.settings.map((s) => s.soundQuality),
      builder: (_, snap) {
        final known = snap.data != null;
        void set(SoundQuality v) => h.setSettings(_S(soundQuality: v));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(l.freeClip2SoundQuality),
              subtitle: Text(l.freeClip2SoundQualityDesc),
            ),
            for (final (value, label) in [
              (SoundQuality.connectivity, l.freeClip2SoundQualityConnectivity),
              (SoundQuality.quality, l.freeClip2SoundQualityQuality),
            ])
              ListTileRadio<SoundQuality>(
                dense: true,
                title: Text(label),
                value: value,
                groupValue: snap.data,
                onChanged: known ? set : null,
              ),
          ],
        );
      },
    );
  }
}

/// One gesture: a radio list per clip, or a single one if the device keeps
/// one setting for both clips (it then reports only the left value)
class _Gesture extends StatelessWidget {
  final _H h;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations)? subtitle;
  final List<int> fallback;
  final String Function(AppLocalizations, int) label;
  final (int?, int?, List<int>?) Function(_S) read;
  final _S Function(int? left, int? right) write;

  /// Hide entirely until the device reports this gesture (optional ones)
  final bool hideUntilKnown;

  /// Title the single card "Both clips" (false: no card title at all)
  final bool bothTitle;

  const _Gesture(
    this.h, {
    required this.title,
    this.subtitle,
    required this.fallback,
    this.label = gestureActionLabel,
    required this.read,
    required this.write,
    this.hideUntilKnown = false,
    this.bothTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    return StreamBuilder<(int?, int?, List<int>?)>(
      stream: h.settings.map(read),
      builder: (_, snap) {
        final (left, right, deviceOptions) = snap.data ?? (null, null, null);
        final waiting = left == null && right == null;
        if (waiting && hideUntilKnown) return const SizedBox.shrink();
        // trust the device about what it accepts; keep the current value
        // visible even if it's something we don't know
        final allowed = deviceOptions ?? fallback;
        final options = [
          ...allowed,
          for (final v in {left, right})
            if (v != null && !allowed.contains(v)) v,
        ];
        final perSide = right != null;

        Widget side(String? sideTitle, int? value, _S Function(int) onPick) =>
            Expanded(
              child: _Side(
                title: sideTitle,
                options: options,
                label: (o) => label(l, o),
                value: value,
                onChanged: waiting ? null : (v) => h.setSettings(onPick(v)),
              ),
            );

        final sub = waiting ? l.freeClip2Waiting : subtitle?.call(l);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(title(l), style: tt.titleMedium),
              subtitle: sub != null ? Text(sub) : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: perSide
                    ? [
                        side(l.pageHeadphonesSettingsLeftBud, left,
                            (v) => write(v, null)),
                        side(l.pageHeadphonesSettingsRightBud, right,
                            (v) => write(null, v)),
                      ]
                    : [
                        side(bothTitle ? l.freeClip2BothBuds : null, left,
                            (v) => write(v, null)),
                      ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Side extends StatelessWidget {
  final String? title;
  final List<int> options;
  final String Function(int) label;
  final int? value;
  final ValueChanged<int>? onChanged;

  const _Side({
    required this.title,
    required this.options,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
              child: Text(title!, style: tt.titleMedium),
            ),
            const Divider(indent: 32, endIndent: 32),
          ] else
            const SizedBox(height: 4),
          for (final o in options)
            ListTileRadio<int>(
              dense: true,
              title: Text(label(o)),
              value: o,
              groupValue: value,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}
