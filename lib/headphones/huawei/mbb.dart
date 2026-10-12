import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:crclib/catalog.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../logger.dart';

/// Helper class for Mbb protocol used to communicate with headphones
///
/// Packet layout: `5A LL LL 00 service command [TLV args...] CRC CRC`, where
/// `LL LL` (big endian) is "args length + 2 checksum bytes + 1".
class MbbUtils {
  /// Magic byte that starts every packet
  static const magic = 0x5A;

  /// Total packet length, given the 16-bit length field
  static int getLengthFromLengthField(int lengthField) => lengthField + 3 + 2;

  /// Get Crc16Xmodem checksum of [data] as Uin8List of two bytes
  static Uint8List checksum(List<int> data) {
    final crc = Crc16Xmodem().convert(data);
    // NOTE: There was a fat-ass bug here: crc didn't pad the first number with
    // 0, so every time byte was like this, whole message was rejected :/
    final str = crc.toRadixString(16).padLeft(4, '0');
    final hexes = [str.substring(0, 2), str.substring(2)];
    final bytes = hexes.map((hex) => int.parse(hex, radix: 16));
    return Uint8List.fromList(bytes.toList());
  }

  /// Checks if checksums are alright
  static bool verifyChecksum(Uint8List payload) {
    final sum = checksum(payload.sublist(0, payload.length - 2));
    return sum[0] == payload[payload.length - 2] &&
        sum[1] == payload[payload.length - 1];
  }

  /// Will throw exception if anything wrong. Otherwise does nothing.
  static void verifyIntegrity(Uint8List payload) {
    // 1 magic, 2 length, 1 zero, 1 service, 1 command, 2 checksum
    if (payload.length < 1 + 2 + 1 + 1 + 1 + 2) {
      throw FormatException("Payload $payload is too short");
    }
    if (payload[0] != magic || payload[3] != 0) {
      throw FormatException("Payload $payload has invalid magic bytes");
    }
    final lengthField = (payload[1] << 8) | payload[2];
    if (getLengthFromLengthField(lengthField) != payload.length) {
      throw FormatException(
          "Length data from $payload doesn't match length field");
    }
    if (!verifyChecksum(payload)) {
      throw FormatException("Checksum from $payload doesn't match");
    }
  }
}

/// Splits raw serial data into whole MBB packets
///
/// Bluetooth serial doesn't care about our packet boundaries - one read can
/// contain half a packet, or three of them. This keeps the leftovers until the
/// rest arrives, and skips garbage until the next magic byte.
class MbbFramer {
  /// Anything claiming to be longer than this is garbage, not a packet
  static const maxPacketLength = 4096;

  final _buffer = <int>[];

  /// Feed [data], get all packets that are complete now
  List<Uint8List> add(List<int> data) {
    _buffer.addAll(data);
    final packets = <Uint8List>[];
    while (true) {
      final start = _buffer.indexOf(MbbUtils.magic);
      if (start < 0) {
        _buffer.clear();
        break;
      }
      if (start > 0) _buffer.removeRange(0, start);
      if (_buffer.length < 4) break;
      final total =
          MbbUtils.getLengthFromLengthField((_buffer[1] << 8) | _buffer[2]);
      if (_buffer[3] != 0 || total > maxPacketLength) {
        // false magic byte - skip it and look for the next one
        _buffer.removeAt(0);
        continue;
      }
      if (_buffer.length < total) break;
      packets.add(Uint8List.fromList(_buffer.sublist(0, total)));
      _buffer.removeRange(0, total);
    }
    return packets;
  }
}

/// Helper class to contain info about single command
/// Also parses it and generates payload
class MbbCommand {
  final int serviceId;
  final int commandId;
  final Map<int, List<int>> args;

  const MbbCommand(this.serviceId, this.commandId, [this.args = const {}]);

  /// Is the command *about* the same thing as [other]? Not necessary same args
  ///
  /// Compares serviceId and commandId
  bool isAbout(MbbCommand other) =>
      serviceId == other.serviceId && commandId == other.commandId;

  @override
  String toString() => 'MbbCommand(serviceId: $serviceId, '
      'commandId: $commandId, dataArgs: $args)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MbbCommand &&
          runtimeType == other.runtimeType &&
          serviceId == other.serviceId &&
          commandId == other.commandId &&
          const DeepCollectionEquality().equals(args, other.args);

  @override
  int get hashCode =>
      serviceId.hashCode ^
      commandId.hashCode ^
      const DeepCollectionEquality().hash(args);

  /// Convert to binary data to be sent to headphones
  Uint8List toPayload() {
    final data = <int>[];
    args.forEach((key, value) {
      data.add(key);
      data.add(value.length);
      data.addAll(value);
    });
    final lengthField = data.length + 2 + 1; // +2->checksums +1->*because*
    final bytesList = [
      MbbUtils.magic,
      lengthField >> 8,
      lengthField & 0xFF,
      0, // another magic byte (i think)
      serviceId,
      commandId,
      ...data.map((b) => b & 0xFF),
    ];
    return Uint8List.fromList(bytesList..addAll(MbbUtils.checksum(bytesList)));
  }

  /// Parse one whole packet (see [MbbFramer] for splitting raw data)
  static MbbCommand fromPacket(Uint8List packet, {bool verify = true}) {
    if (verify) MbbUtils.verifyIntegrity(packet);
    final serviceId = packet[4];
    final commandId = packet[5];
    final dataBytes = packet.sublist(6, packet.length - 2);

    final args = <int, List<int>>{};
    var offset = 0;
    while (offset + 2 <= dataBytes.length) {
      final argId = dataBytes[offset];
      final argLength = dataBytes[offset + 1];
      final end = offset + 2 + argLength;
      if (end > dataBytes.length) {
        throw FormatException("Argument $argId of $packet is too long");
      }
      args[argId] = dataBytes.sublist(offset + 2, end);
      offset = end;
    }
    return MbbCommand(serviceId, commandId, args);
  }

  /// Parse every packet in [payload]
  static List<MbbCommand> fromPayload(Uint8List payload, {bool verify = true}) {
    final packets = MbbFramer().add(payload);
    if (packets.isEmpty && verify) {
      throw FormatException("No commands found in $payload");
    }
    return [for (final p in packets) fromPacket(p, verify: verify)];
  }
}

StreamChannel<MbbCommand> mbbChannel(StreamChannel<Uint8List> rfcomm) {
  final framer = MbbFramer();
  return rfcomm.transform(
    StreamChannelTransformer(
      StreamTransformer.fromHandlers(
        handleData: (data, stream) {
          for (final packet in framer.add(data)) {
            final MbbCommand cmd;
            try {
              cmd = MbbCommand.fromPacket(packet);
            } on FormatException catch (e) {
              // one broken packet shouldn't take down the ones around it
              logg.w("Skipping invalid MBB packet: $e");
              continue;
            }
            // FILTER THE SHIT OUT
            if (cmd.serviceId == 10 && cmd.commandId == 13) continue;
            stream.add(cmd);
          }
        },
      ),
      StreamSinkTransformer.fromHandlers(
        handleData: (data, sink) => rfcomm.sink.add(data.toPayload()),
      ),
    ),
  );
}
