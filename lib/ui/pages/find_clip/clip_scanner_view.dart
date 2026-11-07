import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../headphones/huawei/ble_finder.dart';
import '../../../platform_stuff/android/clip_scanner.dart';

/// Hot/cold finder for a clip that is NOT connected: listens for the clip's
/// own Bluetooth LE advertisements. Also lists every Huawei signal heard, with
/// raw bytes to copy - nobody documented what a FreeClip 2 advertises yet.
class ClipScannerView extends StatefulWidget {
  final Stream<BleSighting> Function() scan;
  final Future<List<String>> Function() bondedClips;
  final Future<bool> Function() requestPermissions;
  final Future<bool> Function() locationServiceOn;

  const ClipScannerView({
    super.key,
    this.scan = ClipScanner.scan,
    this.bondedClips = ClipScanner.bondedClipAddresses,
    this.requestPermissions = ClipScanner.requestPermissions,
    this.locationServiceOn = ClipScanner.locationServiceOn,
  });

  @override
  State<ClipScannerView> createState() => _ClipScannerViewState();
}

enum _Phase { starting, noPermission, scanning, error }

class _ClipScannerViewState extends State<ClipScannerView> {
  _Phase _phase = _Phase.starting;
  String? _error;
  bool _locationOff = false;
  bool _showAll = false;
  String? _selected;
  BleFinder _finder = BleFinder(const []);
  StreamSubscription<BleSighting>? _sub;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _stopScan();
    setState(() => _phase = _Phase.starting);
    if (!await widget.requestPermissions()) {
      if (mounted) setState(() => _phase = _Phase.noPermission);
      return;
    }
    final bonded = await widget.bondedClips().catchError((_) => <String>[]);
    final locationOn = await widget.locationServiceOn().catchError((_) => true);
    if (!mounted) return;
    _finder = BleFinder(bonded);
    _sub = widget.scan().listen(
      _finder.add,
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.error;
          _error = e is PlatformException ? e.code : e.toString();
        });
      },
    );
    // redraw a couple of times per second, not on every advertisement
    _ticker = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() {}),
    );
    setState(() {
      _phase = _Phase.scanning;
      _locationOff = !locationOn;
    });
  }

  Future<void> _stopScan() async {
    _ticker?.cancel();
    _ticker = null;
    await _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    final l = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.diagnosticsCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return switch (_phase) {
      _Phase.starting => const Center(child: CircularProgressIndicator()),
      _Phase.noPermission => _Message(
          icon: Icons.bluetooth_searching,
          text: l.scanPermission,
          actions: [
            FilledButton(onPressed: _start, child: Text(l.scanGrant)),
            TextButton(
              onPressed: openAppSettings,
              child: Text(l.scanOpenSettings),
            ),
          ],
        ),
      _Phase.error => _Message(
          icon: Icons.bluetooth_disabled,
          text: _error == 'BT_OFF' ? l.scanBtOff : l.scanError(_error ?? '?'),
          actions: [FilledButton(onPressed: _start, child: Text(l.scanRetry))],
        ),
      _Phase.scanning => _scanning(context, l),
    };
  }

  Widget _scanning(BuildContext context, AppLocalizations l) {
    final t = Theme.of(context);
    final now = DateTime.now();
    final devices = _finder.devices(now, showAll: _showAll);
    final target =
        devices.where((d) => d.last.address == _selected).firstOrNull ??
            devices.where((d) => d.rank < 3).firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l.scanIntro, style: t.textTheme.bodyMedium),
        if (_locationOff)
          Card(
            color: t.colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.location_off),
              title: Text(l.scanLocationOff),
            ),
          ),
        const SizedBox(height: 8),
        if (target != null)
          _TargetCard(target, now)
        else
          _Message(icon: Icons.radar, text: l.scanWaiting, busy: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l.scanDevices(devices.length),
                style: t.textTheme.titleSmall!
                    .copyWith(color: t.colorScheme.primary),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l.scanCopyAll),
              onPressed: devices.isEmpty
                  ? null
                  : () =>
                      _copy(devices.map((d) => d.last.describe()).join('\n')),
            ),
          ],
        ),
        SwitchListTile(
          dense: true,
          title: Text(l.scanShowAll),
          value: _showAll,
          onChanged: (v) => setState(() => _showAll = v),
        ),
        for (final d in devices)
          _DeviceTile(
            d,
            now,
            selected: d == target,
            onTap: () => setState(() => _selected = d.last.address),
            onCopy: () => _copy(d.last.describe()),
          ),
      ],
    );
  }
}

String _matchLabel(AppLocalizations l, TrackedDevice d) => switch (d.match) {
      ClipMatch.exact => l.scanMatchExact,
      ClipMatch.sameFamily => l.scanMatchFamily,
      ClipMatch.none => d.huawei ? l.scanMatchHuawei : '',
    };

/// The signal being followed: big hot/cold label + meter + trend
class _TargetCard extends StatelessWidget {
  final TrackedDevice d;
  final DateTime now;

  const _TargetCard(this.d, this.now);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = Theme.of(context);
    final rssi = d.tracker.smoothed ?? -100;
    final prox = proximityOf(rssi);
    final (label, color) = switch (prox) {
      Proximity.veryClose => (l.scanProxVeryClose, t.colorScheme.error),
      Proximity.hot => (l.scanProxHot, t.colorScheme.tertiary),
      Proximity.warm => (l.scanProxWarm, t.colorScheme.secondary),
      Proximity.cold => (l.scanProxCold, t.colorScheme.outline),
    };
    final (trendIcon, trendText) = switch (d.tracker.trend) {
      Trend.closer => (Icons.trending_up, l.scanTrendCloser),
      Trend.farther => (Icons.trending_down, l.scanTrendFarther),
      Trend.steady => (Icons.trending_flat, l.scanTrendSteady),
    };
    final ago = now.difference(d.last.time).inSeconds;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              [_matchLabel(l, d), d.last.name ?? d.last.address]
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: t.textTheme.displaySmall!.copyWith(color: color),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 14,
                value: ((rssi + 100) / 60).clamp(0.0, 1.0),
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            // wraps on narrow phones instead of overflowing
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Icon(trendIcon, size: 20),
                Text(trendText),
                Text('· ${rssi.round()} dBm · ${l.scanSeenAgo(ago)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final TrackedDevice d;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  const _DeviceTile(
    this.d,
    this.now, {
    required this.selected,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final match = _matchLabel(l, d);
    final rssi = d.tracker.smoothed?.round();
    return ListTile(
      dense: true,
      selected: selected,
      leading: Icon(switch (d.match) {
        ClipMatch.exact || ClipMatch.sameFamily => Icons.headphones,
        ClipMatch.none => d.huawei ? Icons.bluetooth : Icons.bluetooth_disabled,
      }),
      title: Text(d.last.name ?? d.last.address),
      subtitle: Text([
        if (d.last.name != null) d.last.address,
        '$rssi dBm',
        l.scanSeenAgo(now.difference(d.last.time).inSeconds),
        if (match.isNotEmpty) match,
      ].join(' · ')),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 18),
        tooltip: l.diagnosticsCopy,
        onPressed: onCopy,
      ),
      onTap: onTap,
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final List<Widget> actions;
  final bool busy;

  const _Message({
    required this.icon,
    required this.text,
    this.actions = const [],
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}
