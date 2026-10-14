# FreeClip Buddy 🧷

Open source companion app for **HUAWEI FreeClip 2**: battery, gestures and settings without HUAWEI AI Life.

It is a personal fork of [FreeBuddy](https://github.com/TheLastGimbus/FreeBuddy) by TheLastGimbus, trimmed down to FreeClip 2 only. The FreeClip 2 protocol details come from [OpenFreebuds](https://github.com/melianmiko/OpenFreebuds) by melianmiko.

## Features

- Battery of left clip, right clip and case, plus a home screen widget
- Double tap, triple tap and touch-and-hold actions per clip, plus double tap and hold during calls
- Swipe action, auto pause, dual connection, low latency, sound quality preference
- Diagnostics page (Settings → Diagnostics): raw Bluetooth traffic, device info and a manual command sender, to figure out what the clips really accept
- English, Italian and Polish

Gesture menus only offer the actions the clips report as allowed, so the app can't store an action the clips ignore.

## Install

Grab the APK from the latest **Build apk** run in the [Actions tab](https://github.com/xrayDJ/FreeBuddy/actions/workflows/build_apk.yml) (artifact `freebuddy-nightly`). It is signed with debug keys.

The Android package is `com.xraydj.freeclipbuddy`, so it installs next to the original FreeBuddy. Uninstall the old one to avoid two apps fighting over the clips.

Only one app at a time can talk to the clips. If nothing loads, close HUAWEI AI Life.

## Build

Flutter version is pinned in `.fvm/fvm_config.json` (3.27.1).

```
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze lib test
flutter test
flutter build apk --target-platform android-arm64
```

Translations (English, Italian, Polish) live in one table in `tool/gen_arb.py`. Edit it, then run `python3 tool/gen_arb.py` to rewrite `lib/l10n/*.arb`.

## License

GPL-3.0, like FreeBuddy and OpenFreebuds.
