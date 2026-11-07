import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../cubit/headphones_connection_cubit.dart';
import '../../../cubit/headphones_cubit_objects.dart';
import '../../../headphones/framework/bluetooth_headphones.dart';
import '../../../headphones/framework/headphones_settings.dart';
import '../../../headphones/framework/lrc_battery.dart';
import '../../../headphones/huawei/settings.dart';
import '../../../platform_stuff/android/find_clip.dart';
import '../../common/headphones_connection_ensuring_overlay.dart';
import '../home/controls/battery_card.dart';
import 'clip_scanner_view.dart';

/// Find a clip: make the connected one beep, or search nearby for one that
/// isn't connected anymore by its own Bluetooth signal
class FindClipPage extends StatelessWidget {
  /// Route argument that opens the "search nearby" tab
  static const scanTab = 'scan';

  final Widget scanner;

  const FindClipPage({super.key, this.scanner = const ClipScannerView()});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final connected = context.read<HeadphonesConnectionCubit>().state
        is HeadphonesConnectedOpen;
    final askedScan = ModalRoute.of(context)?.settings.arguments == scanTab;
    return DefaultTabController(
      length: 2,
      // a disconnected clip can't ring - go straight to the scanner
      initialIndex: askedScan || !connected ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.findClipTitle),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.volume_up), text: l.findClipTabRing),
              Tab(icon: const Icon(Icons.radar), text: l.findClipTabScan),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Center(
              child: HeadphonesConnectionEnsuringOverlay(
                builder: (_, h) => _FindClipBody(h),
              ),
            ),
            scanner,
          ],
        ),
      ),
    );
  }
}

class _FindClipBody extends StatefulWidget {
  final BluetoothHeadphones h;

  const _FindClipBody(this.h);

  @override
  State<_FindClipBody> createState() => _FindClipBodyState();
}

class _FindClipBodyState extends State<_FindClipBody> {
  bool _beeping = false;

  /// Auto pause was on before we started - turn it back on when we stop
  bool _restoreAutoPause = false;

  HeadphonesSettings<HuaweiFreeClip2Settings>? get _settings =>
      switch (widget.h) {
        HeadphonesSettings<HuaweiFreeClip2Settings> s => s,
        _ => null,
      };

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _start() async {
    final l = AppLocalizations.of(context)!;
    final s = _settings;
    // wear detection could pause the audio of a clip nobody is wearing
    if (s != null && s.settings.valueOrNull?.autoPause == true) {
      await s.setSettings(const HuaweiFreeClip2Settings(autoPause: false));
      _restoreAutoPause = true;
    }
    try {
      await FindClip.start();
      if (mounted) setState(() => _beeping = true);
    } on PlatformException catch (_) {
      await _restore();
      if (mounted) _snack(l.findClipError);
    } on MissingPluginException catch (_) {
      await _restore();
      if (mounted) _snack(l.findClipError);
    }
  }

  Future<void> _stop() async {
    if (_beeping) {
      try {
        await FindClip.stop();
      } on Exception catch (_) {}
    }
    if (mounted) setState(() => _beeping = false);
    await _restore();
  }

  Future<void> _restore() async {
    if (!_restoreAutoPause) return;
    _restoreAutoPause = false;
    await _settings?.setSettings(
      const HuaweiFreeClip2Settings(autoPause: true),
    );
  }

  @override
  void dispose() {
    // leaving the page always stops the beep
    if (_beeping) FindClip.stop().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = Theme.of(context);
    final tt = t.textTheme;

    Widget tip(IconData icon, String text) => ListTile(
          leading: Icon(icon),
          title: Text(text),
        );

    return BlocListener<HeadphonesConnectionCubit, HeadphonesConnectionState>(
      // if the clip drops, Android would send the beep to the phone speaker
      listener: (context, state) {
        if (state is! HeadphonesConnectedOpen && _beeping) {
          _stop();
          _snack(l.findClipLost);
        }
      },
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: t.colorScheme.errorContainer,
                  child: ListTile(
                    leading: Icon(
                      Icons.hearing_disabled,
                      color: t.colorScheme.onErrorContainer,
                    ),
                    title: Text(
                      l.findClipWarning,
                      style: TextStyle(color: t.colorScheme.onErrorContainer),
                    ),
                  ),
                ),
                tip(Icons.inventory_2_outlined, l.findClipTipCase),
                tip(Icons.wifi_tethering, l.findClipTipRange),
                tip(Icons.battery_std, l.findClipTipBattery),
                if (widget.h is LRCBattery) BatteryCard(widget.h as LRCBattery),
              ],
            ),
          ),
          // the main button stays on screen, whatever the phone size
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 64,
                    child: _beeping
                        ? FilledButton.tonalIcon(
                            icon: const Icon(Icons.stop),
                            label: Text(l.findClipStop,
                                style: const TextStyle(fontSize: 16)),
                            onPressed: _stop,
                          )
                        : FilledButton.icon(
                            icon: const Icon(Icons.volume_up),
                            label: Text(l.findClipStart,
                                style: const TextStyle(fontSize: 16)),
                            onPressed: _start,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      l.findClipVolumeNote,
                      style: tt.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
