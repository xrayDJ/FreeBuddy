import 'package:rxdart/rxdart.dart';

import '../../framework/bluetooth_headphones.dart';
import '../../framework/headphones_info.dart';
import '../../framework/headphones_settings.dart';
import '../../framework/lrc_battery.dart';
import '../settings.dart';

/// Base abstract class for HUAWEI FreeClip 2.
///
/// No [Anc] here - it's open-ear, no noise cancelling.
abstract base class HuaweiFreeClip2
    implements
        BluetoothHeadphones,
        HeadphonesModelInfo,
        LRCBattery,
        HeadphonesSettings<HuaweiFreeClip2Settings> {
  const HuaweiFreeClip2();

  @override
  String get vendor => "Huawei";

  @override
  String get name => "FreeClip 2";

  @override
  ValueStream<String> get imageAssetPath =>
      BehaviorSubject.seeded('assets/app_icons/ic_launcher.png');

  static final idNameRegex =
      RegExp(r'^(?=(HUAWEI FreeClip 2))', caseSensitive: true);
}
