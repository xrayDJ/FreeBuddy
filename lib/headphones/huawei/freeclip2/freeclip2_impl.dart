import 'dart:async';
import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:the_last_bluetooth/the_last_bluetooth.dart' as tlb;

import '../../../logger.dart';
import '../../framework/lrc_battery.dart';
import '../mbb.dart';
import '../mbb_diagnostics.dart';
import '../settings.dart';
import 'freeclip2.dart';

/// HUAWEI FreeClip 2 over the Huawei SPP ("MBB") protocol.
///
/// Command IDs and parameter layouts ported from OpenFreebuds'
/// `OfbDriverHuaweiFreeClip2` (GPL-3.0, melianmiko/OpenFreebuds).
final class HuaweiFreeClip2Impl extends HuaweiFreeClip2
    implements MbbDiagnostics {
  final tlb.BluetoothDevice _bluetoothDevice;
  final StreamChannel<MbbCommand> _mbb;

  /// How long to wait for the device to confirm a write before re-reading
  final Duration _writeReplyTimeout;

  final _bluetoothAliasCtrl = BehaviorSubject<String>();
  final _lrcBatteryCtrl = BehaviorSubject<LRCBatteryLevels>();
  final _settingsCtrl = BehaviorSubject<HuaweiFreeClip2Settings>();
  final _deviceInfoCtrl = BehaviorSubject<Map<String, String>>();
  final _traceCtrl = BehaviorSubject<List<MbbTraceEntry>>.seeded(const []);
  final _incoming = StreamController<MbbCommand>.broadcast();

  /// How many packets the diagnostics page keeps
  static const traceLength = 300;

  /// Read requests that already got a (parseable) reply. The watchdog
  /// re-sends only the ones still missing, so an unknown code from the device
  /// doesn't cause endless re-polling.
  final _answered = <MbbCommand>{};
  int _watchdogRuns = 0;
  bool _closed = false;

  /// Give up re-requesting after this many watchdog ticks (3s each)
  static const _watchdogMaxRuns = 20;

  late StreamSubscription _watchdogStreamSub;

  HuaweiFreeClip2Impl(
    this._mbb,
    this._bluetoothDevice, {
    Duration writeReplyTimeout = const Duration(seconds: 1),
  }) : _writeReplyTimeout = writeReplyTimeout {
    final aliasStreamSub = _bluetoothDevice.alias
        .listen((alias) => _bluetoothAliasCtrl.add(alias));
    _bluetoothAliasCtrl.onCancel = () => aliasStreamSub.cancel();

    _mbb.stream.listen(
      (cmd) {
        _trace(false, cmd);
        _incoming.add(cmd);
        try {
          _evalMbbCommand(cmd);
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
        _deviceInfoCtrl.close();
        _traceCtrl.close();
        _incoming.close();
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

  void _trace(bool outgoing, MbbCommand cmd) {
    if (_traceCtrl.isClosed) return;
    final list = [
      ..._traceCtrl.value,
      MbbTraceEntry(DateTime.now(), outgoing, cmd)
    ];
    _traceCtrl.add(list.length > traceLength
        ? list.sublist(list.length - traceLength)
        : list);
  }

  void _send(MbbCommand cmd) {
    if (_closed) return;
    _trace(true, cmd);
    _mbb.sink.add(cmd);
  }

  /// Send [write], wait (a bit) for the device to answer it, then send
  /// [reread] so the UI shows what the device actually stored
  Future<void> _write(MbbCommand write, MbbCommand? reread) async {
    if (_closed) return;
    final reply = _incoming.stream
        .firstWhere((c) => c.isAbout(write))
        .timeout(_writeReplyTimeout);
    _send(write);
    try {
      await reply;
    } on TimeoutException {
      logg.w("No reply to write $write");
    } catch (_) {
      return; // connection closed while waiting
    }
    if (reread != null) _send(reread);
  }

  /// Gesture read replies: 1 = left, 2 = right, 3 = actions the device allows
  static ({int? left, int? right, List<int>? options})? _gesture(
    Map<int, List<int>> a,
  ) {
    int? one(int id) => a[id]?.length == 1 ? _s8(a[id]![0]) : null;
    final left = one(1);
    final right = one(2);
    if (left == null && right == null) return null;
    final opts = a[3];
    return (
      left: left,
      right: right,
      options: opts == null || opts.isEmpty ? null : opts.map(_s8).toList(),
    );
  }

  void _evalMbbCommand(MbbCommand cmd) {
    final last = _settingsCtrl.valueOrNull ?? const HuaweiFreeClip2Settings();
    final a = cmd.args;
    int? one(int id) => a[id]?.length == 1 ? a[id]![0] : null;

    // # Battery (read reply 1/8 or notify 1/39)
    if (cmd.serviceId == 1 && (cmd.commandId == 8 || cmd.commandId == 39)) {
      final level = a[2];
      final status = a[3];
      if (level == null || status == null) return;
      if (level.length < 3 || status.length < 3) return;
      _answered.add(_Cmd.getBattery);
      _lrcBatteryCtrl.add(LRCBatteryLevels(
        level[0] == 0 ? null : level[0],
        level[1] == 0 ? null : level[1],
        level[2] == 0 ? null : level[2],
        status[0] == 1,
        status[1] == 1,
        status[2] == 1,
      ));
    } else if (cmd.isAbout(_Cmd.getDeviceInfo)) {
      final info = _parseDeviceInfo(a);
      if (info.isEmpty) return;
      _answered.add(_Cmd.getDeviceInfo);
      _deviceInfoCtrl.add(info);
    } else if (cmd.isAbout(_Cmd.getDoubleTap)) {
      final g = _gesture(a);
      if (g == null) return;
      _answered.add(_Cmd.getDoubleTap);
      _settingsCtrl.add(last.copyWith(
        doubleTapLeft: g.left,
        doubleTapRight: g.right,
        doubleTapOptions: g.options,
      ));
    } else if (cmd.isAbout(_Cmd.getTripleTap)) {
      final g = _gesture(a);
      if (g == null) return;
      _answered.add(_Cmd.getTripleTap);
      _settingsCtrl.add(last.copyWith(
        tripleTapLeft: g.left,
        tripleTapRight: g.right,
        tripleTapOptions: g.options,
      ));
    } else if (cmd.isAbout(_Cmd.getLongPress)) {
      final g = _gesture(a);
      if (g == null) return;
      _answered.add(_Cmd.getLongPress);
      _settingsCtrl.add(last.copyWith(
        longPressLeft: g.left,
        longPressRight: g.right,
        longPressOptions: g.options,
      ));
    } else if (cmd.isAbout(_Cmd.getSwipe)) {
      final v = one(1);
      if (v == null) return;
      _answered.add(_Cmd.getSwipe);
      _settingsCtrl.add(last.copyWith(swipeVolume: _s8(v) == 0));
    } else if (cmd.isAbout(_Cmd.getAutoPause)) {
      final v = one(1);
      if (v == null) return;
      _answered.add(_Cmd.getAutoPause);
      _settingsCtrl.add(last.copyWith(autoPause: v == 1));
    } else if (cmd.isAbout(_Cmd.getLowLatency)) {
      // read reply carries the value in param 2 (write reply doesn't)
      final v = one(2);
      if (v == null) return;
      _answered.add(_Cmd.getLowLatency);
      _settingsCtrl.add(last.copyWith(lowLatency: v == 1));
    } else if (cmd.isAbout(_Cmd.getSoundQuality)) {
      // reply carries the value in param 2
      final v = one(2);
      if (v == null) return;
      _answered.add(_Cmd.getSoundQuality);
      _settingsCtrl.add(last.copyWith(
        soundQuality: v == 1 ? SoundQuality.quality : SoundQuality.connectivity,
      ));
    } else if (cmd.isAbout(_Cmd.getDualConnect)) {
      final v = one(1);
      if (v == null) return;
      _answered.add(_Cmd.getDualConnect);
      _settingsCtrl.add(last.copyWith(dualConnect: v == 1));
    }
  }

  /// Field ids from OpenFreebuds' OfbHuaweiInfoHandler
  static const _deviceInfoFields = {
    15: 'Model',
    10: 'Submodel',
    7: 'Firmware',
    3: 'Hardware',
    9: 'Serial number',
  };

  static Map<String, String> _parseDeviceInfo(Map<int, List<int>> a) {
    final out = <String, String>{};
    for (final MapEntry(key: id, value: name) in _deviceInfoFields.entries) {
      final bytes = a[id];
      if (bytes == null || bytes.isEmpty) continue;
      final text = utf8
          .decode(bytes, allowMalformed: true)
          .replaceAll('\u0000', '')
          .trim();
      if (text.isNotEmpty) out[name] = text;
    }
    return out;
  }

  void _requestMissingInfo() {
    for (final c in _Cmd.allGetters) {
      if (!_answered.contains(c)) _send(c);
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
  ValueStream<Map<String, String>> get deviceInfo => _deviceInfoCtrl.stream;

  @override
  ValueStream<List<MbbTraceEntry>> get mbbTrace => _traceCtrl.stream;

  @override
  Future<void> sendRaw(MbbCommand command) async => _send(command);

  @override
  Future<void> rereadAll() async {
    _answered.clear();
    _requestMissingInfo();
  }

  @override
  Future<void> setSettings(HuaweiFreeClip2Settings n) async {
    final p = _settingsCtrl.valueOrNull ?? const HuaweiFreeClip2Settings();
    bool changed(Object? next, Object? prev) => next != null && next != prev;

    if (changed(n.doubleTapLeft, p.doubleTapLeft)) {
      await _write(_Cmd.doubleTap(1, n.doubleTapLeft!), _Cmd.getDoubleTap);
    }
    if (changed(n.doubleTapRight, p.doubleTapRight)) {
      await _write(_Cmd.doubleTap(2, n.doubleTapRight!), _Cmd.getDoubleTap);
    }
    if (changed(n.tripleTapLeft, p.tripleTapLeft)) {
      await _write(_Cmd.tripleTap(1, n.tripleTapLeft!), _Cmd.getTripleTap);
    }
    if (changed(n.tripleTapRight, p.tripleTapRight)) {
      await _write(_Cmd.tripleTap(2, n.tripleTapRight!), _Cmd.getTripleTap);
    }
    if (changed(n.longPressLeft, p.longPressLeft)) {
      await _write(_Cmd.longPress(1, n.longPressLeft!), _Cmd.getLongPress);
    }
    if (changed(n.longPressRight, p.longPressRight)) {
      await _write(_Cmd.longPress(2, n.longPressRight!), _Cmd.getLongPress);
    }
    if (changed(n.swipeVolume, p.swipeVolume)) {
      await _write(_Cmd.swipe(n.swipeVolume!), _Cmd.getSwipe);
    }
    if (changed(n.autoPause, p.autoPause)) {
      await _write(_Cmd.autoPause(n.autoPause!), _Cmd.getAutoPause);
    }
    if (changed(n.lowLatency, p.lowLatency)) {
      await _write(_Cmd.lowLatency(n.lowLatency!), null);
      // device needs a moment before it reports the new value
      unawaited(Future.delayed(const Duration(seconds: 1), () {
        if (!_closed) _send(_Cmd.getLowLatency);
      }));
    }
    if (changed(n.soundQuality, p.soundQuality)) {
      await _write(_Cmd.soundQuality(n.soundQuality!), _Cmd.getSoundQuality);
    }
    if (changed(n.dualConnect, p.dualConnect)) {
      await _write(_Cmd.dualConnect(n.dualConnect!), _Cmd.getDualConnect);
    }
  }
}

/// Magic numbers. Service/command IDs from OpenFreebuds spp_commands.py
abstract class _Cmd {
  // 0x01 0x08
  static const getBattery = MbbCommand(1, 8, {1: [], 2: [], 3: []});

  // 0x01 0x07 - ask for every field, like OpenFreebuds does
  static final getDeviceInfo =
      MbbCommand(1, 7, {for (var i = 0; i < 32; i++) i: const []});

  // 0x01 0x20 / 0x01 0x1f
  static const getDoubleTap = MbbCommand(1, 32, {1: [], 2: []});
  static MbbCommand doubleTap(int side, int action) => MbbCommand(1, 31, {
        side: [action & 0xFF]
      });

  // 0x01 0x26 / 0x01 0x25
  static const getTripleTap = MbbCommand(1, 38, {1: [], 2: []});
  static MbbCommand tripleTap(int side, int action) => MbbCommand(1, 37, {
        side: [action & 0xFF]
      });

  // 0x2b 0x17 / 0x2b 0x16
  static const getLongPress = MbbCommand(43, 23, {1: [], 2: []});
  static MbbCommand longPress(int side, int action) => MbbCommand(43, 22, {
        side: [action & 0xFF]
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
  static final allGetters = [
    getBattery,
    getDeviceInfo,
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
