import 'dart:async';

import 'package:collection/collection.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:the_last_bluetooth/the_last_bluetooth.dart' as tlb;

import '../../../logger.dart';
import '../../framework/lrc_battery.dart';
import '../mbb.dart';
import '../settings.dart';
import 'freeclip2.dart';

/// HUAWEI FreeClip 2 over the Huawei SPP ("MBB") protocol.
///
/// Command IDs and parameter layouts ported from OpenFreebuds'
/// `OfbDriverHuaweiFreeClip2` (GPL-3.0, melianmiko/OpenFreebuds).
final class HuaweiFreeClip2Impl extends HuaweiFreeClip2 {
  final tlb.BluetoothDevice _bluetoothDevice;
  final StreamChannel<MbbCommand> _mbb;

  final _bluetoothAliasCtrl = BehaviorSubject<String>();
  final _lrcBatteryCtrl = BehaviorSubject<LRCBatteryLevels>();
  final _settingsCtrl = BehaviorSubject<HuaweiFreeClip2Settings>();

  /// Read requests that already got a (parseable) reply. The watchdog
  /// re-sends only the ones still missing, so an unknown code from the device
  /// (e.g. a gesture action we don't model) doesn't cause endless re-polling.
  final _answered = <MbbCommand>{};
  int _watchdogRuns = 0;
  bool _closed = false;

  /// Give up re-requesting after this many watchdog ticks (3s each)
  static const _watchdogMaxRuns = 20;

  late StreamSubscription _watchdogStreamSub;

  HuaweiFreeClip2Impl(this._mbb, this._bluetoothDevice) {
    final aliasStreamSub = _bluetoothDevice.alias
        .listen((alias) => _bluetoothAliasCtrl.add(alias));
    _bluetoothAliasCtrl.onCancel = () => aliasStreamSub.cancel();

    _mbb.stream.listen(
      (e) {
        try {
          _evalMbbCommand(e);
        } catch (e, s) {
          logg.e(e, stackTrace: s);
        }
      },
      onError: logg.onError,
      onDone: () {
        _closed = true;
        _watchdogStreamSub.cancel();
        _bluetoothAliasCtrl.close();
        _lrcBatteryCtrl.close();
        _settingsCtrl.close();
      },
    );
    _requestMissingInfo();
    _watchdogStreamSub =
        Stream.periodic(const Duration(seconds: 3)).listen((_) {
      if (_watchdogRuns++ >= _watchdogMaxRuns) {
        _watchdogStreamSub.cancel();
        return;
      }
      _requestMissingInfo();
    });
  }

  // signed byte helper: device sends -1 as 0xFF
  static int _s8(int b) => b > 127 ? b - 256 : b;

  void _evalMbbCommand(MbbCommand cmd) {
    final last = _settingsCtrl.valueOrNull ?? const HuaweiFreeClip2Settings();
    switch (cmd.args) {
      // # Battery (read reply 1/8 or notify 1/39)
      case {2: var level, 3: var status}
          when cmd.serviceId == 1 &&
              (cmd.commandId == 8 || cmd.commandId == 39) &&
              level.length >= 3 &&
              status.length >= 3:
        _answered.add(_Cmd.getBattery);
        _lrcBatteryCtrl.add(LRCBatteryLevels(
          level[0] == 0 ? null : level[0],
          level[1] == 0 ? null : level[1],
          level[2] == 0 ? null : level[2],
          status[0] == 1,
          status[1] == 1,
          status[2] == 1,
        ));
        break;
      // # Double tap
      case {1: [var l, ...], 2: [var r, ...]}
          when cmd.isAbout(_Cmd.getDoubleTap):
        _answered.add(_Cmd.getDoubleTap);
        _settingsCtrl.add(last.copyWith(
          doubleTapLeft: _tapFromCode(_s8(l)),
          doubleTapRight: _tapFromCode(_s8(r)),
        ));
        break;
      // # Triple tap
      case {1: [var l, ...], 2: [var r, ...]}
          when cmd.isAbout(_Cmd.getTripleTap):
        _answered.add(_Cmd.getTripleTap);
        _settingsCtrl.add(last.copyWith(
          tripleTapLeft: _tapFromCode(_s8(l)),
          tripleTapRight: _tapFromCode(_s8(r)),
        ));
        break;
      // # Long press
      case {1: [var l, ...], 2: [var r, ...]}
          when cmd.isAbout(_Cmd.getLongPress):
        _answered.add(_Cmd.getLongPress);
        _settingsCtrl.add(last.copyWith(
          longPressLeft: _longFromCode(_s8(l)),
          longPressRight: _longFromCode(_s8(r)),
        ));
        break;
      // # Swipe
      case {1: [var v, ...]} when cmd.isAbout(_Cmd.getSwipe):
        _answered.add(_Cmd.getSwipe);
        _settingsCtrl.add(last.copyWith(swipeVolume: _s8(v) == 0));
        break;
      // # Auto pause
      case {1: [var v, ...]} when cmd.isAbout(_Cmd.getAutoPause):
        _answered.add(_Cmd.getAutoPause);
        _settingsCtrl.add(last.copyWith(autoPause: v == 1));
        break;
      // # Low latency (read reply carries value in param 2)
      case {2: [var v, ...]} when cmd.isAbout(_Cmd.getLowLatency):
        _answered.add(_Cmd.getLowLatency);
        _settingsCtrl.add(last.copyWith(lowLatency: v == 1));
        break;
      // # Sound quality (reply carries value in param 2)
      case {2: [var v, ...]} when cmd.isAbout(_Cmd.getSoundQuality):
        _answered.add(_Cmd.getSoundQuality);
        _settingsCtrl.add(last.copyWith(
          soundQuality:
              v == 1 ? SoundQuality.quality : SoundQuality.connectivity,
        ));
        break;
      // # Dual connect enabled
      case {1: [var v, ...]} when cmd.isAbout(_Cmd.getDualConnect):
        _answered.add(_Cmd.getDualConnect);
        _settingsCtrl.add(last.copyWith(dualConnect: v == 1));
        break;
    }
  }

  void _requestMissingInfo() {
    for (final c in _Cmd.allGetters) {
      if (!_answered.contains(c)) _mbb.sink.add(c);
    }
  }

  @override
  ValueStream<int> get batteryLevel => _bluetoothDevice.battery;

  @override
  ValueStream<String> get bluetoothAlias => _bluetoothAliasCtrl.stream;

  @override
  String get bluetoothName => _bluetoothDevice.name.valueOrNull ?? "Unknown";

  @override
  String get macAddress => _bluetoothDevice.mac;

  @override
  ValueStream<LRCBatteryLevels> get lrcBattery => _lrcBatteryCtrl.stream;

  @override
  ValueStream<HuaweiFreeClip2Settings> get settings => _settingsCtrl.stream;

  @override
  Future<void> setSettings(HuaweiFreeClip2Settings n) async {
    final p = _settingsCtrl.valueOrNull ?? const HuaweiFreeClip2Settings();
    void reread(MbbCommand c) => _mbb.sink.add(c);

    if (n.doubleTapLeft != null && n.doubleTapLeft != p.doubleTapLeft) {
      _mbb.sink.add(_Cmd.doubleTap(1, n.doubleTapLeft!));
      reread(_Cmd.getDoubleTap);
    }
    if (n.doubleTapRight != null && n.doubleTapRight != p.doubleTapRight) {
      _mbb.sink.add(_Cmd.doubleTap(2, n.doubleTapRight!));
      reread(_Cmd.getDoubleTap);
    }
    if (n.tripleTapLeft != null && n.tripleTapLeft != p.tripleTapLeft) {
      _mbb.sink.add(_Cmd.tripleTap(1, n.tripleTapLeft!));
      reread(_Cmd.getTripleTap);
    }
    if (n.tripleTapRight != null && n.tripleTapRight != p.tripleTapRight) {
      _mbb.sink.add(_Cmd.tripleTap(2, n.tripleTapRight!));
      reread(_Cmd.getTripleTap);
    }
    if (n.longPressLeft != null && n.longPressLeft != p.longPressLeft) {
      _mbb.sink.add(_Cmd.longPress(1, n.longPressLeft!));
      reread(_Cmd.getLongPress);
    }
    if (n.longPressRight != null && n.longPressRight != p.longPressRight) {
      _mbb.sink.add(_Cmd.longPress(2, n.longPressRight!));
      reread(_Cmd.getLongPress);
    }
    if (n.swipeVolume != null && n.swipeVolume != p.swipeVolume) {
      _mbb.sink.add(_Cmd.swipe(n.swipeVolume!));
      reread(_Cmd.getSwipe);
    }
    if (n.autoPause != null && n.autoPause != p.autoPause) {
      _mbb.sink.add(_Cmd.autoPause(n.autoPause!));
      reread(_Cmd.getAutoPause);
    }
    if (n.lowLatency != null && n.lowLatency != p.lowLatency) {
      _mbb.sink.add(_Cmd.lowLatency(n.lowLatency!));
      // device needs a moment before it reports the new value
      unawaited(Future.delayed(const Duration(seconds: 1), () {
        if (!_closed) reread(_Cmd.getLowLatency);
      }));
    }
    if (n.soundQuality != null && n.soundQuality != p.soundQuality) {
      _mbb.sink.add(_Cmd.soundQuality(n.soundQuality!));
      reread(_Cmd.getSoundQuality);
    }
    if (n.dualConnect != null && n.dualConnect != p.dualConnect) {
      _mbb.sink.add(_Cmd.dualConnect(n.dualConnect!));
      reread(_Cmd.getDualConnect);
    }
  }

  static DoubleTap? _tapFromCode(int c) =>
      DoubleTap.values.firstWhereOrNull((e) => e.mbbCode == c);

  static LongPress? _longFromCode(int c) =>
      LongPress.values.firstWhereOrNull((e) => e.mbbCode == c);
}

/// Magic numbers. Service/command IDs from OpenFreebuds spp_commands.py
abstract class _Cmd {
  // 0x01 0x08
  static const getBattery = MbbCommand(1, 8, {1: [], 2: [], 3: []});

  // 0x01 0x20 / 0x01 0x1f
  static const getDoubleTap = MbbCommand(1, 32, {1: [], 2: []});
  static MbbCommand doubleTap(int side, DoubleTap a) => MbbCommand(1, 31, {
        side: [a.mbbCode & 0xFF]
      });

  // 0x01 0x26 / 0x01 0x25
  static const getTripleTap = MbbCommand(1, 38, {1: [], 2: []});
  static MbbCommand tripleTap(int side, DoubleTap a) => MbbCommand(1, 37, {
        side: [a.mbbCode & 0xFF]
      });

  // 0x2b 0x17 / 0x2b 0x16
  static const getLongPress = MbbCommand(43, 23, {1: [], 2: []});
  static MbbCommand longPress(int side, LongPress a) => MbbCommand(43, 22, {
        side: [a.mbbCode & 0xFF]
      });

  // 0x2b 0x1f / 0x2b 0x1e  (-1 = off, 0 = volume)
  static const getSwipe = MbbCommand(43, 31, {1: [], 2: []});
  static MbbCommand swipe(bool volume) => MbbCommand(43, 30, {
        1: [volume ? 0 : 255],
        2: [volume ? 0 : 255],
      });

  // 0x2b 0x11 / 0x2b 0x10
  static const getAutoPause = MbbCommand(43, 17, {1: []});
  static MbbCommand autoPause(bool on) => MbbCommand(43, 16, {
        1: [on ? 1 : 0]
      });

  // 0x2b 0x6c : read with param 2, write with param 1
  static const getLowLatency = MbbCommand(43, 108, {2: []});
  static MbbCommand lowLatency(bool on) => MbbCommand(43, 108, {
        1: [on ? 1 : 0]
      });

  // 0x2b 0xa3 read / 0x2b 0xa2 write
  static const getSoundQuality = MbbCommand(43, 163, {1: []});
  static MbbCommand soundQuality(SoundQuality q) => MbbCommand(43, 162, {
        1: [q == SoundQuality.quality ? 1 : 0]
      });

  // 0x2b 0x2f read / 0x2b 0x2e write
  static const getDualConnect = MbbCommand(43, 47, {1: []});
  static MbbCommand dualConnect(bool on) => MbbCommand(43, 46, {
        1: [on ? 1 : 0]
      });

  /// Everything we ask for on connect
  static const allGetters = [
    getBattery,
    getDoubleTap,
    getTripleTap,
    getLongPress,
    getSwipe,
    getAutoPause,
    getLowLatency,
    getSoundQuality,
    getDualConnect,
  ];
}

extension _FC2Tap on DoubleTap {
  int get mbbCode => switch (this) {
        DoubleTap.nothing => -1,
        DoubleTap.voiceAssistant => 0,
        DoubleTap.playPause => 1,
        DoubleTap.next => 2,
        DoubleTap.previous => 7,
      };
}

extension _FC2Long on LongPress {
  int get mbbCode => switch (this) {
        LongPress.nothing => -1,
        LongPress.voiceAssistant => 0,
        LongPress.volumeUp => 18,
        LongPress.volumeDown => 19,
      };
}
