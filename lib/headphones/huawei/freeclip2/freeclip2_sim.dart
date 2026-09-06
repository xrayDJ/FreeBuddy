import 'package:rxdart/rxdart.dart';

import '../../framework/simulators/bluetooth_headphones_sim.dart';
import '../../framework/simulators/lrc_battery_sim.dart';
import '../settings.dart';
import 'freeclip2.dart';

final class HuaweiFreeClip2Sim extends HuaweiFreeClip2
    with BluetoothHeadphonesSim, LRCBatteryAlwaysFullSim {
  final _settingsCtrl = BehaviorSubject<HuaweiFreeClip2Settings>.seeded(
    const HuaweiFreeClip2Settings(
      doubleTapLeft: DoubleTap.playPause,
      doubleTapRight: DoubleTap.playPause,
      tripleTapLeft: DoubleTap.next,
      tripleTapRight: DoubleTap.next,
      longPressLeft: LongPress.voiceAssistant,
      longPressRight: LongPress.voiceAssistant,
      swipeVolume: true,
      autoPause: true,
      lowLatency: false,
      dualConnect: true,
      soundQuality: SoundQuality.connectivity,
    ),
  );

  @override
  ValueStream<HuaweiFreeClip2Settings> get settings => _settingsCtrl.stream;

  @override
  Future<void> setSettings(HuaweiFreeClip2Settings n) async {
    _settingsCtrl.add(_settingsCtrl.value.copyWith(
      doubleTapLeft: n.doubleTapLeft,
      doubleTapRight: n.doubleTapRight,
      tripleTapLeft: n.tripleTapLeft,
      tripleTapRight: n.tripleTapRight,
      longPressLeft: n.longPressLeft,
      longPressRight: n.longPressRight,
      swipeVolume: n.swipeVolume,
      autoPause: n.autoPause,
      lowLatency: n.lowLatency,
      dualConnect: n.dualConnect,
      soundQuality: n.soundQuality,
    ));
  }
}

final class HuaweiFreeClip2SimPlaceholder extends HuaweiFreeClip2
    with BluetoothHeadphonesSimPlaceholder, LRCBatteryAlwaysFullSimPlaceholder {
  const HuaweiFreeClip2SimPlaceholder();

  @override
  ValueStream<HuaweiFreeClip2Settings> get settings => BehaviorSubject();

  @override
  Future<void> setSettings(HuaweiFreeClip2Settings newSettings) async {}
}
