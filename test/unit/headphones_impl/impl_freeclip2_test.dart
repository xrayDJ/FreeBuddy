import 'dart:async';
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

void main() {
  group("FreeClip 2 implementation tests", () {
    // "info" tests check if impl reacts to data *from* buds
    // "set" tests check if impl sends correct bytes *to* buds

    late StreamController<Uint8List> inputCtrl;
    late StreamController<Uint8List> outputCtrl;
    late StreamChannel<Uint8List> channel;
    late HuaweiFreeClip2Impl fc2;
    setUp(() {
      inputCtrl = StreamController<Uint8List>.broadcast();
      outputCtrl = StreamController<Uint8List>();
      channel = StreamChannel<Uint8List>(inputCtrl.stream, outputCtrl.sink);
      fc2 = HuaweiFreeClip2Impl(mbbChannel(channel), const FakeBtDev());
    });
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
          [90, 0, 7, 0, 1, 32, 1, 0, 2, 0, 232, 151], // double tap
          [90, 0, 7, 0, 1, 38, 1, 0, 2, 0, 37, 18], // triple tap
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
    test("Gesture info (signed -1 = off)", () async {
      inputCtrl.add(const MbbCommand(1, 32, {
        1: [1],
        2: [255],
      }).toPayload());
      inputCtrl.add(const MbbCommand(1, 38, {
        1: [2],
        2: [7],
      }).toPayload());
      inputCtrl.add(const MbbCommand(43, 23, {
        1: [18],
        2: [0],
      }).toPayload());
      expect(
        fc2.settings.map((s) => (
              s.doubleTapLeft,
              s.doubleTapRight,
              s.tripleTapLeft,
              s.tripleTapRight,
              s.longPressLeft,
              s.longPressRight,
            )),
        emitsThrough((
          DoubleTap.playPause,
          DoubleTap.nothing,
          DoubleTap.next,
          DoubleTap.previous,
          LongPress.volumeUp,
          LongPress.voiceAssistant,
        )),
      );
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
    test("Settings set", () async {
      await fc2.setSettings(const HuaweiFreeClip2Settings(
        doubleTapRight: DoubleTap.next,
        tripleTapLeft: DoubleTap.nothing,
        longPressLeft: LongPress.volumeUp,
        swipeVolume: false,
        autoPause: true,
        lowLatency: true,
        soundQuality: SoundQuality.quality,
        dualConnect: false,
      ));
      // 9 initial reads + 8 writes + 7 immediate re-reads (low latency
      // re-read is delayed by a second, so not counted here)
      final sent = await outputCtrl.stream.bytesToList().take(24).toList();
      expect(
        sent,
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
    test("Properly closes", () async {
      expectLater(fc2.lrcBattery, emitsDone);
      expectLater(fc2.settings, emitsDone);
      await inputCtrl.close();
    });
  });
}

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
