import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../headphones/framework/bluetooth_headphones.dart';
import '../../../../headphones/framework/headphones_info.dart';
import '../../../../headphones/framework/headphones_settings.dart';
import '../../../../headphones/framework/lrc_battery.dart';
import '../../../theme/layouts.dart';
import 'battery_card.dart';
import 'headphones_image.dart';

/// Main whole-screen widget with controls for headphones
///
/// It contains battery, buttons to find a clip and to settings etc - just give it
/// the [headphones] and all done ☺
///
/// ...in fact, it is built so simple that you can freely hot-swap the
/// headphones object - for example, if they disconnect for a moment,
/// you can give it [HeadphonesMockNever] object, and previous values will stay
/// because it won't override them
class HeadphonesControlsWidget extends StatelessWidget {
  final BluetoothHeadphones headphones;

  const HeadphonesControlsWidget({super.key, required this.headphones});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tt = t.textTheme;
    // TODO here:
    // - [ ] Make this clearer - this padding shouldn't be here?
    // - [ ] De-duplicate responsive stuff
    // - [ ] Think what to put when we have no image, or generally not many
    //       features 🤷
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: WindowSizeClass.of(context) == WindowSizeClass.compact
          ? Column(
              children: [
                StreamBuilder(
                  stream: headphones.bluetoothAlias,
                  builder: (_, snap) => Text(
                    snap.data ?? headphones.bluetoothName,
                    style: tt.headlineMedium,
                  ),
                ),
                if (headphones is HeadphonesModelInfo)
                  HeadphonesImage(headphones as HeadphonesModelInfo)
                else
                  // TODO: This is ugly. Very
                  const Expanded(child: Icon(Icons.headphones, size: 64)),
                _ActionButtons(
                  showSettings: headphones is HeadphonesSettings,
                ),
                if (headphones is LRCBattery)
                  BatteryCard(headphones as LRCBattery),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      StreamBuilder(
                        stream: headphones.bluetoothAlias,
                        builder: (_, snap) => Text(
                          snap.data ?? headphones.bluetoothName,
                          style: tt.headlineMedium,
                        ),
                      ),
                      if (headphones is HeadphonesModelInfo)
                        HeadphonesImage(headphones as HeadphonesModelInfo)
                      else
                        // TODO: This is ugly. Very
                        const Expanded(child: Icon(Icons.headphones, size: 64)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _ActionButtons(
                          showSettings: headphones is HeadphonesSettings,
                        ),
                        if (headphones is LRCBattery)
                          BatteryCard(headphones as LRCBattery),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// "Find" and "Settings" buttons above the battery card
class _ActionButtons extends StatelessWidget {
  final bool showSettings;

  const _ActionButtons({required this.showSettings});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        children: [
          _RouteButton(
            icon: Icons.travel_explore,
            label: l.findClipHomeButton,
            route: '/find_clip',
          ),
          if (showSettings)
            _RouteButton(
              icon: Icons.settings_outlined,
              label: l.settings,
              route: '/headphones_settings',
            ),
        ],
      ),
    );
  }
}

/// Small outlined button that opens [route]
class _RouteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _RouteButton({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      // TODO: Move this to theme stuff some day
      padding: t.cardTheme.margin ?? const EdgeInsets.all(4.0),
      child: OutlinedButton(
        onPressed: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
