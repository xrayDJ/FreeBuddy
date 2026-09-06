import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../headphones/framework/headphones_settings.dart';
import '../../../../headphones/huawei/settings.dart';
import '../../../common/list_tile_radio.dart';
import '../../../common/list_tile_switch.dart';

typedef _H = HeadphonesSettings<HuaweiFreeClip2Settings>;

/// All FreeClip 2 settings in one place
List<Widget> freeClip2SettingsWidgets(
  HeadphonesSettings<HuaweiFreeClip2Settings> h,
) =>
    [
      _Toggle(
        h,
        (l) => (l.autoPause, l.autoPauseDesc),
        (s) => s.autoPause,
        (v) => HuaweiFreeClip2Settings(autoPause: v),
      ),
      _Toggle(
        h,
        (l) => (l.freeClip2Swipe, l.freeClip2SwipeDesc),
        (s) => s.swipeVolume,
        (v) => HuaweiFreeClip2Settings(swipeVolume: v),
      ),
      _Toggle(
        h,
        (l) => (l.freeClip2DualConnect, l.freeClip2DualConnectDesc),
        (s) => s.dualConnect,
        (v) => HuaweiFreeClip2Settings(dualConnect: v),
      ),
      _Toggle(
        h,
        (l) => (l.freeClip2LowLatency, l.freeClip2LowLatencyDesc),
        (s) => s.lowLatency,
        (v) => HuaweiFreeClip2Settings(lowLatency: v),
      ),
      const Divider(indent: 16, endIndent: 16),
      _SoundQuality(h),
      const Divider(indent: 16, endIndent: 16),
      _Gesture<DoubleTap>(
        h,
        (l) => l.pageHeadphonesSettingsDoubleTap,
        DoubleTap.values,
        _tapLabel,
        (s) => (s.doubleTapLeft, s.doubleTapRight),
        (l, r) => HuaweiFreeClip2Settings(doubleTapLeft: l, doubleTapRight: r),
      ),
      const Divider(indent: 16, endIndent: 16),
      _Gesture<DoubleTap>(
        h,
        (l) => l.freeClip2TripleTap,
        DoubleTap.values,
        _tapLabel,
        (s) => (s.tripleTapLeft, s.tripleTapRight),
        (l, r) => HuaweiFreeClip2Settings(tripleTapLeft: l, tripleTapRight: r),
      ),
      const Divider(indent: 16, endIndent: 16),
      _Gesture<LongPress>(
        h,
        (l) => l.pageHeadphonesSettingsHold,
        LongPress.values,
        _longLabel,
        (s) => (s.longPressLeft, s.longPressRight),
        (l, r) => HuaweiFreeClip2Settings(longPressLeft: l, longPressRight: r),
      ),
      const SizedBox(height: 64),
    ];

String _tapLabel(AppLocalizations l, DoubleTap t) => switch (t) {
      DoubleTap.nothing => l.pageHeadphonesSettingsDoubleTapNone,
      DoubleTap.voiceAssistant => l.pageHeadphonesSettingsDoubleTapAssist,
      DoubleTap.playPause => l.pageHeadphonesSettingsDoubleTapPlayPause,
      DoubleTap.next => l.pageHeadphonesSettingsDoubleTapNextSong,
      DoubleTap.previous => l.pageHeadphonesSettingsDoubleTapPrevSong,
    };

String _longLabel(AppLocalizations l, LongPress t) => switch (t) {
      LongPress.nothing => l.pageHeadphonesSettingsDoubleTapNone,
      LongPress.voiceAssistant => l.pageHeadphonesSettingsDoubleTapAssist,
      LongPress.volumeUp => l.freeClip2VolumeUp,
      LongPress.volumeDown => l.freeClip2VolumeDown,
    };

class _Toggle extends StatelessWidget {
  final _H h;
  final (String, String) Function(AppLocalizations) texts;
  final bool? Function(HuaweiFreeClip2Settings) read;
  final HuaweiFreeClip2Settings Function(bool) write;

  const _Toggle(this.h, this.texts, this.read, this.write);

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = texts(AppLocalizations.of(context)!);
    return StreamBuilder<bool?>(
      stream: h.settings.map(read),
      initialData: false,
      builder: (_, snap) => ListTileSwitch(
        title: Text(title),
        subtitle: Text(subtitle),
        value: snap.data ?? false,
        onChanged: (v) => h.setSettings(write(v)),
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
      builder: (_, snap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(l.freeClip2SoundQuality),
            subtitle: Text(l.freeClip2SoundQualityDesc),
          ),
          ListTileRadio<SoundQuality>(
            dense: true,
            title: Text(l.freeClip2SoundQualityConnectivity),
            value: SoundQuality.connectivity,
            groupValue: snap.data,
            onChanged: (v) =>
                h.setSettings(HuaweiFreeClip2Settings(soundQuality: v)),
          ),
          ListTileRadio<SoundQuality>(
            dense: true,
            title: Text(l.freeClip2SoundQualityQuality),
            value: SoundQuality.quality,
            groupValue: snap.data,
            onChanged: (v) =>
                h.setSettings(HuaweiFreeClip2Settings(soundQuality: v)),
          ),
        ],
      ),
    );
  }
}

/// A "left bud / right bud" pair of radio lists for one gesture
class _Gesture<T> extends StatelessWidget {
  final _H h;
  final String Function(AppLocalizations) title;
  final List<T> options;
  final String Function(AppLocalizations, T) label;
  final (T?, T?) Function(HuaweiFreeClip2Settings) read;
  final HuaweiFreeClip2Settings Function(T?, T?) write;

  const _Gesture(
    this.h,
    this.title,
    this.options,
    this.label,
    this.read,
    this.write,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    return StreamBuilder<(T?, T?)>(
      stream: h.settings.map(read),
      builder: (_, snap) {
        final left = snap.data?.$1;
        final right = snap.data?.$2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(title: Text(title(l), style: tt.titleMedium)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Side<T>(
                      title: l.pageHeadphonesSettingsLeftBud,
                      options: options,
                      label: (o) => label(l, o),
                      value: left,
                      onChanged: (v) => h.setSettings(write(v, null)),
                    ),
                  ),
                  Expanded(
                    child: _Side<T>(
                      title: l.pageHeadphonesSettingsRightBud,
                      options: options,
                      label: (o) => label(l, o),
                      value: right,
                      onChanged: (v) => h.setSettings(write(null, v)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Side<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final String Function(T) label;
  final T? value;
  final ValueChanged<T> onChanged;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
            child: Text(title, style: tt.titleMedium),
          ),
          const Divider(indent: 32, endIndent: 32),
          for (final o in options)
            ListTileRadio<T>(
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
