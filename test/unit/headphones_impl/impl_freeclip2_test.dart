import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freebuddy/headphones/framework/lrc_battery.dart';
import 'package:freebuddy/headphones/huawei/freeclip2/freeclip2.dart';
import 'package:freebuddy/headphones/huawei/freeclip2/freeclip2_impl.dart';
import 'package:freebuddy/headphones/huawei/mbb.dart';
import 'package:freebuddy/headphones/huawei/settings.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:the_last_bluetooth/the_last_bluetooth.dart';

// Expected bytes below were computed independently (python binascii.crc_hqx)
const _readDeviceInfo = [
  90, 0, 67, 0, 1, 7, //
  0, 0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0, 9, 0, 10, 0, //
  11, 0, 12, 0, 13, 0, 14, 0, 15, 0, 16, 0, 17, 0, 18, 0, 19, 0, 20, 0, //
  21, 0, 22, 0, 23, 0, 24, 0, 25, 0, 26, 0, 27, 0, 28, 0, 29, 0, 30, 0, //
  31, 0, 139, 233,
];
const _readTripleTap = [90, 0, 7, 0, 1, 38, 1, 0, 2, 0, 37, 18];
const _writeTripleTapLeftNext = [90, 0, 6, 0, 1, 37, 1, 1, 2, 71, 131];

void main() {
  group("FreeClip 2 implementation tests", () {
    // "info" tests check if impl reacts to data *from* buds
    // "set" tests check if impl sends correct bytes *to* buds

    late StreamController<Uint8List> inputCtrl;
    late StreamController<Uint8List> outputCtrl;
    late HuaweiFreeClip2Impl fc2;

    HuaweiFreeClip2Impl create(Duration writeReplyTimeout) {
      inputCtrl = StreamController<Uint8List>.broadcast();
      outputCtrl = StreamController<Uint8List>();
      final channel =
          StreamChannel<Uint8List>(inputCtrl.stream, outputCtrl.sink);
      return HuaweiFreeClip2Impl(
        mbbChannel(channel),
        const FakeBtDev(),
        writeReplyTimeout: writeReplyTimeout,
      );
    }

    setUp(() => fc2 = create(const Duration(milliseconds: 10)));
    tearDown(() {
      inputCtrl.close();
      outputCtrl.close();
    });

    test("Name regex", () {
      expect(HuaweiFreeClip2.idNameRegex.hasMatch("HUAWEI FreeClip 2"), true);
      // 1st gen FreeClip is a different (ANC-capable) protocol - don't match
      expect(HuaweiFreeClip2.idNameRegex.hasMatch("HUAWEI FreeClip"), false);
      expect(HuaweiFreeClip2.idNameRegex.hasMatch("HUAWEI FreeBuds 4i"), false);
    });

    test("Request data on start", () async {
      expect(
        outputCtrl.stream.bytesToList(),
        emitsInAnyOrder([
          [90, 0, 9, 0, 1, 8, 1, 0, 2, 0, 3, 0, 251, 185], // battery
          _readDeviceInfo,
          [90, 0, 7, 0, 1, 32, 1, 0, 2, 0, 232, 151], // double tap
          _readTripleTap,
          [90, 0, 7, 0, 43, 23, 1, 0, 2, 0, 48, 167], // long press
          [90, 0, 7, 0, 43, 31, 1, 0, 2, 0, 50, 138], // swipe
          [90, 0, 5, 0, 43, 17, 1, 0, 119, 42], // auto pause
          [90, 0, 5, 0, 43, 108, 2, 0, 184, 32], // low latency (param 2!)
          [90, 0, 5, 0, 43, 163, 1, 0, 231, 181], // sound quality
          [90, 0, 5, 0, 43, 47, 1, 0, 169, 142], // dual connect
        ]),
      );
    });

    test("Battery info", () async {
      inputCtrl.add(const MbbCommand(1, 39, {
        1: [35],
        2: [35, 70, 99],
        3: [1, 0, 1]
      }).toPayload());
      expect(
        fc2.lrcBattery,
        emits(const LRCBatteryLevels(35, 70, 99, true, false, true)),
      );
    });

    test("Gesture info: signed codes and allowed actions (param 3)", () async {
      inputCtrl.add(const MbbCommand(1, 32, {
        1: [1],
        2: [255],
        3: [255, 1, 2, 7, 0],
      }).toPayload());
      inputCtrl.add(const MbbCommand(1, 38, {
        1: [2],
        2: [7],
        3: [255, 2, 7],
      }).toPayload());
      // long press: one value for both clips, no param 2
      inputCtrl.add(const MbbCommand(43, 23, {
        1: [18],
        3: [255, 0, 18, 19],
      }).toPayload());
      expect(
        fc2.settings.map((s) => (
              s.doubleTapLeft,
              s.doubleTapRight,
              s.doubleTapOptions?.join(','), // lists compare by identity
              s.tripleTapLeft,
              s.tripleTapRight,
              s.tripleTapOptions?.join(','), // lists compare by identity
              s.longPressLeft,
              s.longPressRight,
              s.longPressOptions?.join(','), // lists compare by identity
            )),
        emitsThrough((
          GestureAction.playPause,
          GestureAction.off,
          '-1,1,2,7,0',
          GestureAction.next,
          GestureAction.previous,
          '-1,2,7',
          GestureAction.volumeUp,
          null,
          '-1,0,18,19',
        )),
      );
    });

    test("Unknown gesture code is kept, not dropped", () async {
      inputCtrl.add(const MbbCommand(43, 23, {
        1: [10], // "switch ANC" leftover from other models
      }).toPayload());
      expect(fc2.settings.map((s) => s.longPressLeft), emitsThrough(10));
    });

    test("Toggles info", () async {
      inputCtrl.add(const MbbCommand(43, 31, {
        1: [255],
        2: [255],
      }).toPayload());
      inputCtrl.add(const MbbCommand(43, 17, {
        1: [1],
      }).toPayload());
      // low latency and sound quality report in param 2
      inputCtrl.add(const MbbCommand(43, 108, {
        2: [1],
      }).toPayload());
      inputCtrl.add(const MbbCommand(43, 163, {
        1: [0],
        2: [1],
      }).toPayload());
      inputCtrl.add(const MbbCommand(43, 47, {
        1: [0],
      }).toPayload());
      expect(
        fc2.settings.map((s) => (
              s.swipeVolume,
              s.autoPause,
              s.lowLatency,
              s.soundQuality,
              s.dualConnect,
            )),
        emitsThrough((false, true, true, SoundQuality.quality, false)),
      );
    });

    test("Low latency write reply doesn't look like a value", () async {
      inputCtrl.add(const MbbCommand(43, 108, {
        127: [0, 1, 134, 160],
      }).toPayload());
      await pumpEventQueue();
      expect(fc2.settings.valueOrNull?.lowLatency, null);
    });

    test("Device info", () async {
      inputCtrl.add(MbbCommand(1, 7, {
        3: utf8.encode('HL1SAKM_Ver.A'),
        7: utf8.encode('6.1.0.352'),
        10: utf8.encode('BTFT0027-000167'),
        15: utf8.encode('BTFT0027'),
        20: [1, 2, 3],
      }).toPayload());
      expect(
        fc2.deviceInfo,
        emits({
          'Model': 'BTFT0027',
          'Submodel': 'BTFT0027-000167',
          'Firmware': '6.1.0.352',
          'Hardware': 'HL1SAKM_Ver.A',
        }),
      );
    });

    test("Traffic is traced both ways", () async {
      inputCtrl.add(const MbbCommand(43, 17, {
        1: [1],
      }).toPayload());
      await pumpEventQueue();
      final trace = fc2.mbbTrace.value;
      expect(trace.where((e) => e.outgoing).length, 10);
      expect(
        trace.where((e) => !e.outgoing).single.command,
        const MbbCommand(43, 17, {
          1: [1]
        }),
      );
    });

    test("Settings set", () async {
      final sent = outputCtrl.stream.bytesToList().take(25).toList();
      await fc2.setSettings(const HuaweiFreeClip2Settings(
        doubleTapRight: GestureAction.next,
        tripleTapLeft: GestureAction.off,
        longPressLeft: GestureAction.volumeUp,
        swipeVolume: false,
        autoPause: true,
        lowLatency: true,
        soundQuality: SoundQuality.quality,
        dualConnect: false,
      ));
      // 10 initial reads + 8 writes + 7 re-reads (low latency re-read is
      // delayed by a second, so not counted here)
      expect(
        await sent,
        containsAll([
          [90, 0, 6, 0, 1, 31, 2, 1, 2, 90, 145], // double tap right
          [90, 0, 6, 0, 1, 37, 1, 1, 255, 121, 49], // triple tap left off
          [90, 0, 6, 0, 43, 22, 1, 1, 18, 172, 157], // long press vol up
          [90, 0, 9, 0, 43, 30, 1, 1, 255, 2, 1, 255, 157, 155], // swipe off
          [90, 0, 6, 0, 43, 16, 1, 1, 1, 169, 86], // auto pause on
          [90, 0, 6, 0, 43, 108, 1, 1, 1, 164, 17], // low latency (param 1!)
          [90, 0, 6, 0, 43, 162, 1, 1, 1, 181, 239], // sound quality
          [90, 0, 6, 0, 43, 46, 1, 1, 0, 55, 196], // dual connect off
        ]),
      );
    });

    test("Write waits for the device reply, then re-reads", () async {
      inputCtrl.close();
      outputCtrl.close();
      fc2 = create(const Duration(seconds: 5));
      final sent = <List<int>>[];
      outputCtrl.stream.bytesToList().listen(sent.add);

      final done = fc2.setSettings(
          const HuaweiFreeClip2Settings(tripleTapLeft: GestureAction.next));
      await pumpEventQueue();
      expect(sent.last, _writeTripleTapLeftNext);
      expect(sent.where((p) => _eq(p, _readTripleTap)).length, 1); // initial

      inputCtrl.add(const MbbCommand(1, 37, {
        127: [0, 1, 134, 160]
      }).toPayload());
      await done;
      await pumpEventQueue();
      expect(sent.last, _readTripleTap);
    });

    test("Properly closes", () async {
      expectLater(fc2.lrcBattery, emitsDone);
      expectLater(fc2.settings, emitsDone);
      expectLater(fc2.deviceInfo, emitsDone);
      expectLater(fc2.mbbTrace, emitsThrough(emitsDone));
      await inputCtrl.close();
    });
  });
}

bool _eq(List<int> a, List<int> b) =>
    a.length == b.length &&
    Iterable.generate(a.length).every((i) => a[i] == b[i]);

class FakeBtDev implements BluetoothDevice {
  const FakeBtDev();

  @override
  ValueStream<String> get alias => Stream.value("FreeClip 🧷").shareValue();

  @override
  ValueStream<int> get battery => Stream.value(100).shareValue();

  @override
  ValueStream<bool> get isConnected => Stream.value(true).shareValue();

  @override
  String get mac => "00:11:22:33:44:55";

  @override
  ValueStream<String> get name =>
      Stream.value("HUAWEI FreeClip 2").shareValue();

  @override
  Future<Set<String>> get uuids => Future.value({});
}

extension on Stream<Uint8List> {
  Stream<List<int>> bytesToList() => map((event) => event.toList());
}
