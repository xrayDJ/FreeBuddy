import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freebuddy/headphones/huawei/ble_finder.dart';

final _t0 = DateTime(2026, 11, 7, 12);

BleSighting _s(
  String address,
  int rssi, {
  Duration at = Duration.zero,
  String? name,
  Map<int, Uint8List> mfr = const {},
}) =>
    BleSighting(
      time: _t0.add(at),
      address: address,
      rssi: rssi,
      name: name,
      manufacturerData: mfr,
    );

void main() {
  test("Parse a native scan event", () {
    final s = BleSighting.fromMap({
      'address': 'AA:BB:CC:DD:EE:01',
      'name': null,
      'rssi': -61,
      'manufacturer': {
        0x027D: Uint8List.fromList([1, 2, 255])
      },
      'serviceUuids': ['0000FE86-0000-1000-8000-00805F9B34FB'],
      'serviceData': <Object?, Object?>{},
      'raw': null,
    }, _t0);
    expect(s.rssi, -61);
    expect(s.serviceUuids, [HuaweiBle.serviceUuid]);
    expect(HuaweiBle.isHuawei(s), true);
    expect(s.describe(), contains('mfr[0x027d]=0102ff'));
  });

  test("Huawei detection: company id, service uuid, name", () {
    expect(
      HuaweiBle.isHuawei(_s('A', -50, mfr: {0x027D: Uint8List(0)})),
      true,
    );
    expect(HuaweiBle.isHuawei(_s('A', -50, name: 'HUAWEI FreeClip 2')), true);
    expect(HuaweiBle.isHuawei(_s('A', -50, mfr: {0x004C: Uint8List(0)})),
        false); // Apple
    expect(HuaweiBle.isHuawei(_s('A', -50)), false);
  });

  test("Match against paired clip addresses", () {
    const bonded = ['aa:bb:cc:dd:ee:01'];
    expect(matchClip('AA:BB:CC:DD:EE:01', bonded), ClipMatch.exact);
    expect(matchClip('AA:BB:CC:DD:EE:02', bonded), ClipMatch.sameFamily);
    expect(matchClip('11:22:33:44:55:66', bonded), ClipMatch.none);
  });

  test("Proximity levels", () {
    expect(proximityOf(-50), Proximity.veryClose);
    expect(proximityOf(-60), Proximity.hot);
    expect(proximityOf(-70), Proximity.warm);
    expect(proximityOf(-90), Proximity.cold);
  });

  test("Tracker smooths jumps and drops old samples", () {
    final r = RssiTracker()
      ..add(_t0, -80)
      ..add(_t0.add(const Duration(milliseconds: 500)), -60);
    expect(r.smoothed, -70);
    r.add(_t0.add(const Duration(seconds: 5)), -50);
    expect(r.smoothed, -50); // older ones out of the 2 s window
  });

  test("Trend: closer, farther, steady", () {
    RssiTracker walk(List<int> rssis) {
      final r = RssiTracker();
      for (var i = 0; i < rssis.length; i++) {
        r.add(_t0.add(Duration(milliseconds: 500 * i)), rssis[i]);
      }
      return r;
    }

    expect(walk([-85, -85, -80, -75, -70, -65, -60, -60]).trend, Trend.closer);
    expect(walk([-60, -60, -65, -70, -75, -80, -85, -85]).trend, Trend.farther);
    expect(walk([-70, -71, -69, -70, -70, -71, -70, -69]).trend, Trend.steady);
  });

  test("Finder ranks own clip first, hides non-Huawei, forgets old", () {
    final f = BleFinder(['AA:BB:CC:DD:EE:01'])
      ..add(_s('11:11:11:11:11:11', -40, mfr: {0x004C: Uint8List(0)}))
      ..add(_s('22:22:22:22:22:22', -45, mfr: {0x027D: Uint8List(0)}))
      ..add(_s('AA:BB:CC:DD:EE:02', -90));
    var list = f.devices(_t0);
    expect(list.map((d) => d.last.address),
        ['AA:BB:CC:DD:EE:02', '22:22:22:22:22:22']);
    expect(f.devices(_t0, showAll: true).length, 3);

    f.add(_s('22:22:22:22:22:22', -45,
        at: const Duration(seconds: 40), mfr: {0x027D: Uint8List(0)}));
    list = f.devices(_t0.add(const Duration(seconds: 40)));
    expect(list.map((d) => d.last.address), ['22:22:22:22:22:22']);
  });
}
