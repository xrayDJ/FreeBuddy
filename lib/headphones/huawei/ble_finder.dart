import 'dart:typed_data';

/// One Bluetooth LE advertisement heard by the phone
class BleSighting {
  final DateTime time;
  final String address;
  final String? name;
  final int rssi;
  final Map<int, Uint8List> manufacturerData;
  final List<String> serviceUuids;
  final Map<String, Uint8List> serviceData;
  final Uint8List? raw;

  const BleSighting({
    required this.time,
    required this.address,
    required this.rssi,
    this.name,
    this.manufacturerData = const {},
    this.serviceUuids = const [],
    this.serviceData = const {},
    this.raw,
  });

  /// Parse an event from the native scanner (ClipScanner.kt)
  factory BleSighting.fromMap(Map<Object?, Object?> m, DateTime time) =>
      BleSighting(
        time: time,
        address: m['address'] as String,
        name: m['name'] as String?,
        rssi: m['rssi'] as int,
        manufacturerData: {
          for (final e in ((m['manufacturer'] as Map?) ?? const {}).entries)
            e.key as int: e.value as Uint8List,
        },
        serviceUuids: [
          for (final u in (m['serviceUuids'] as List?) ?? const [])
            (u as String).toLowerCase(),
        ],
        serviceData: {
          for (final e in ((m['serviceData'] as Map?) ?? const {}).entries)
            (e.key as String).toLowerCase(): e.value as Uint8List,
        },
        raw: m['raw'] as Uint8List?,
      );

  /// Plain text with every byte, to paste when reporting what the clips send
  String describe() {
    String hex(List<int> b) =>
        b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    final buf = StringBuffer('$address rssi=$rssi');
    if (name != null) buf.write(' name="$name"');
    for (final e in manufacturerData.entries) {
      buf.write(' mfr[0x${e.key.toRadixString(16).padLeft(4, '0')}]='
          '${hex(e.value)}');
    }
    if (serviceUuids.isNotEmpty) buf.write(' uuids=${serviceUuids.join(',')}');
    for (final e in serviceData.entries) {
      buf.write(' svc[${e.key}]=${hex(e.value)}');
    }
    if (raw != null) buf.write(' raw=${hex(raw!)}');
    return buf.toString();
  }
}

/// Bluetooth SIG ids registered to Huawei
abstract final class HuaweiBle {
  /// Company identifier in manufacturer specific data
  static const companyId = 0x027D;

  /// 16-bit service UUID, in its 128-bit form
  static const serviceUuid = '0000fe86-0000-1000-8000-00805f9b34fb';

  static final _nameRegex = RegExp('huawei|freeclip', caseSensitive: false);

  /// Does this advertisement come from a Huawei device?
  static bool isHuawei(BleSighting s) =>
      s.manufacturerData.containsKey(companyId) ||
      s.serviceUuids.contains(serviceUuid) ||
      s.serviceData.containsKey(serviceUuid) ||
      _nameRegex.hasMatch(s.name ?? '');
}

/// How sure we are that a sighting is one of the user's own clips
enum ClipMatch {
  /// Same address as a paired FreeClip 2
  exact,

  /// Same first 5 bytes: earbuds of one pair usually get consecutive addresses
  sameFamily,
  none,
}

ClipMatch matchClip(String address, Iterable<String> bondedClips) {
  final a = address.toUpperCase();
  String prefix(String s) => s.length >= 14 ? s.substring(0, 14) : s;
  for (final b in bondedClips.map((e) => e.toUpperCase())) {
    if (a == b) return ClipMatch.exact;
  }
  for (final b in bondedClips.map((e) => e.toUpperCase())) {
    if (prefix(a) == prefix(b)) return ClipMatch.sameFamily;
  }
  return ClipMatch.none;
}

/// Hot / cold, from the smoothed signal strength
enum Proximity { cold, warm, hot, veryClose }

Proximity proximityOf(double rssi) => switch (rssi) {
      >= -55 => Proximity.veryClose,
      >= -65 => Proximity.hot,
      >= -78 => Proximity.warm,
      _ => Proximity.cold,
    };

/// Getting closer or farther, from how the signal changed
enum Trend { closer, steady, farther }

/// Smooths the jumpy RSSI of one device and tells the trend
class RssiTracker {
  /// Samples older than this are dropped from the average
  static const window = Duration(seconds: 2);

  /// Signal change (dB) that counts as moving
  static const trendThreshold = 3.0;

  final _samples = <(DateTime, int)>[];
  final _history = <(DateTime, double)>[];

  void add(DateTime time, int rssi) {
    _samples.add((time, rssi));
    _samples.removeWhere((s) => time.difference(s.$1) > window);
    _history.add((time, smoothed!));
    _history.removeWhere((s) => time.difference(s.$1) > window * 3);
  }

  /// Average over the last [window], null until the first sample
  double? get smoothed => _samples.isEmpty
      ? null
      : _samples.map((s) => s.$2).reduce((a, b) => a + b) / _samples.length;

  DateTime? get lastSeen => _samples.isEmpty ? null : _samples.last.$1;

  /// Compares now with the average about [window] ago
  Trend get trend {
    if (_history.length < 2) return Trend.steady;
    final now = _history.last;
    final then = _history.lastWhere(
      (h) => now.$1.difference(h.$1) >= window,
      orElse: () => _history.first,
    );
    final delta = now.$2 - then.$2;
    if (delta >= trendThreshold) return Trend.closer;
    if (delta <= -trendThreshold) return Trend.farther;
    return Trend.steady;
  }
}

/// Everything heard so far, one entry per address
class TrackedDevice {
  final RssiTracker tracker = RssiTracker();
  BleSighting last;
  final ClipMatch match;
  final bool huawei;

  TrackedDevice(this.last, this.match) : huawei = HuaweiBle.isHuawei(last);

  /// Your clip first, then Huawei devices, then the rest
  int get rank => switch ((match, huawei)) {
        (ClipMatch.exact, _) => 0,
        (ClipMatch.sameFamily, _) => 1,
        (_, true) => 2,
        _ => 3,
      };
}

class BleFinder {
  /// Devices not heard for this long disappear from the list
  static const forgetAfter = Duration(seconds: 30);

  final Iterable<String> bondedClips;
  final _devices = <String, TrackedDevice>{};

  BleFinder(this.bondedClips);

  void add(BleSighting s) {
    final d = _devices.putIfAbsent(
      s.address,
      () => TrackedDevice(s, matchClip(s.address, bondedClips)),
    );
    d.last = s;
    d.tracker.add(s.time, s.rssi);
  }

  /// Sorted: likely clips and Huawei devices first, then strongest signal
  List<TrackedDevice> devices(DateTime now, {bool showAll = false}) {
    _devices.removeWhere((_, d) => now.difference(d.last.time) > forgetAfter);
    final list = _devices.values.where((d) => showAll || d.rank < 3).toList()
      ..sort((a, b) {
        final r = a.rank.compareTo(b.rank);
        if (r != 0) return r;
        return (b.tracker.smoothed ?? -200)
            .compareTo(a.tracker.smoothed ?? -200);
      });
    return list;
  }
}
