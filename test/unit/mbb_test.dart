import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freebuddy/headphones/huawei/mbb.dart';
import 'package:freebuddy/headphones/huawei/mbb_diagnostics.dart';
import 'package:stream_channel/stream_channel.dart';

const _readTripleTap = [90, 0, 7, 0, 1, 38, 1, 0, 2, 0, 37, 18];
const _readBattery = [90, 0, 9, 0, 1, 8, 1, 0, 2, 0, 3, 0, 251, 185];

void main() {
  group("MbbFramer", () {
    test("Packet split across two reads", () {
      final f = MbbFramer();
      expect(f.add(_readTripleTap.sublist(0, 5)), isEmpty);
      expect(f.add(_readTripleTap.sublist(5)), [_readTripleTap]);
    });

    test("Two packets in one read", () {
      expect(
        MbbFramer().add([..._readTripleTap, ..._readBattery]),
        [_readTripleTap, _readBattery],
      );
    });

    test("Garbage before a packet is skipped", () {
      expect(
          MbbFramer().add([1, 2, 90, 7, 3, ..._readBattery]), [_readBattery]);
    });
  });

  group("MbbCommand", () {
    test("16-bit length field (packets longer than 255 bytes)", () {
      final cmd = MbbCommand(1, 7, {
        15: List.filled(200, 65),
        7: List.filled(200, 66),
      });
      final payload = cmd.toPayload();
      // computed independently with python binascii.crc_hqx
      expect(payload.length, 412);
      expect(payload.sublist(0, 6), [90, 1, 151, 0, 1, 7]);
      expect(payload.sublist(410), [181, 116]);
      expect(MbbCommand.fromPacket(payload), cmd);
    });

    test("Argument longer than the packet is rejected", () {
      final bad = MbbCommand(1, 8, {
        1: [5, 5]
      }).toPayload();
      bad[7] = 9; // arg 1 claims 9 bytes, has 2
      // fix checksum so only the TLV is wrong
      final fixed = Uint8List.fromList([
        ...bad.sublist(0, bad.length - 2),
        ...MbbUtils.checksum(bad.sublist(0, bad.length - 2)),
      ]);
      expect(() => MbbCommand.fromPacket(fixed), throwsFormatException);
    });
  });

  test("mbbChannel skips a broken packet and keeps the next one", () async {
    final input = StreamController<Uint8List>();
    final channel = mbbChannel(
      StreamChannel(input.stream, StreamController<Uint8List>().sink),
    );
    final broken = [..._readBattery];
    broken[broken.length - 1] ^= 0xFF; // bad checksum
    input.add(Uint8List.fromList([...broken, ..._readTripleTap]));
    expect(
      await channel.stream.first,
      const MbbCommand(1, 38, {1: [], 2: []}),
    );
    await input.close();
  });

  group("parseMbbCommandSpec", () {
    test("Hex ids, empty params", () {
      expect(
        parseMbbCommandSpec('0x01', '0x26', '1= 2='),
        const MbbCommand(1, 38, {1: [], 2: []}),
      );
    });

    test("Decimal ids, hex values", () {
      expect(
        parseMbbCommandSpec('43', '22', '1=ff;2=0012'),
        const MbbCommand(43, 22, {
          1: [255],
          2: [0, 18]
        }),
      );
    });

    test("Bad input throws FormatException", () {
      expect(() => parseMbbCommandSpec('300', '1', ''), throwsFormatException);
      expect(() => parseMbbCommandSpec('1', '1', '1=f'), throwsFormatException);
      expect(() => parseMbbCommandSpec('1', '1', '1'), throwsFormatException);
    });
  });
}
