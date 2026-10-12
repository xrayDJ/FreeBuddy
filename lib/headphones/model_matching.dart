import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';
import 'package:the_last_bluetooth/the_last_bluetooth.dart';

import 'framework/bluetooth_headphones.dart';
import 'huawei/freeclip2/freeclip2.dart';
import 'huawei/freeclip2/freeclip2_impl.dart';
import 'huawei/freeclip2/freeclip2_sim.dart';
import 'huawei/mbb.dart';

typedef HeadphonesBuilder = BluetoothHeadphones Function(
    StreamChannel<Uint8List> io, BluetoothDevice device);

typedef MatchedModel = ({
  HeadphonesBuilder builder,
  BluetoothHeadphones placeholder
});

/// This app supports only HUAWEI FreeClip 2
MatchedModel? matchModel(BluetoothDevice matchedDevice) {
  final name = matchedDevice.name.value;
  if (!HuaweiFreeClip2.idNameRegex.hasMatch(name)) return null;
  return (
    builder: (io, dev) => HuaweiFreeClip2Impl(mbbChannel(io), dev),
    placeholder: const HuaweiFreeClip2SimPlaceholder(),
  );
}
