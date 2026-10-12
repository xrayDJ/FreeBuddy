import 'package:rxdart/rxdart.dart';

import 'mbb.dart';

/// One MBB packet that went to or came from the headphones
class MbbTraceEntry {
  final DateTime time;
  final bool outgoing;
  final MbbCommand command;

  const MbbTraceEntry(this.time, this.outgoing, this.command);

  /// Write replies carry a status in param 127 - not decoded, just shown
  bool get isWriteReply => !outgoing && command.args.containsKey(127);

  String get timeLabel {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}'
        '.${time.millisecond.toString().padLeft(3, '0')}';
  }

  /// `01:26` style id, hex, same as OpenFreebuds and PROTOCOL.md
  String get idLabel => '${hexByte(command.serviceId)}:'
      '${hexByte(command.commandId)}';

  /// `1=01 2=ff 3=(empty)` style args
  String get argsLabel => command.args.isEmpty
      ? '-'
      : command.args.entries
          .map((e) => '${e.key}=${e.value.isEmpty ? '()' : hexBytes(e.value)}')
          .join(' ');

  String get payloadHex => hexBytes(command.toPayload());

  @override
  String toString() => '$timeLabel ${outgoing ? 'TX' : 'RX'} $idLabel '
      '(${command.serviceId},${command.commandId}) $argsLabel';
}

String hexByte(int b) => (b & 0xFF).toRadixString(16).padLeft(2, '0');

String hexBytes(List<int> bytes) => bytes.map(hexByte).join();

/// Headphones that let the diagnostics page look at their raw MBB traffic
abstract class MbbDiagnostics {
  /// Recent traffic, oldest first
  ValueStream<List<MbbTraceEntry>> get mbbTrace;

  /// Model, firmware etc. as reported by the device (command 01:07)
  ValueStream<Map<String, String>> get deviceInfo;

  /// Send any command as-is
  Future<void> sendRaw(MbbCommand command);

  /// Ask the device again for every value the app knows about
  Future<void> rereadAll();
}

/// Parse user input from the diagnostics page into a command
///
/// - [service], [command]: decimal (`43`) or hex with `0x` (`0x2b`)
/// - [args]: `1=01 2=ff 3=` - param id (decimal), then hex bytes; empty value
///   means an empty param, which is how read requests look like
MbbCommand parseMbbCommandSpec(String service, String command, String args) {
  int byte(String s, String what) {
    final t = s.trim().toLowerCase();
    final v = t.startsWith('0x')
        ? int.tryParse(t.substring(2), radix: 16)
        : int.tryParse(t);
    if (v == null || v < 0 || v > 255) {
      throw FormatException('Invalid $what: "$s"');
    }
    return v;
  }

  final parsed = <int, List<int>>{};
  for (final part in args.split(RegExp(r'[\s,;]+'))) {
    if (part.isEmpty) continue;
    final eq = part.indexOf('=');
    if (eq < 0) throw FormatException('Missing "=" in "$part"');
    final id = byte(part.substring(0, eq), 'param id');
    final hex = part.substring(eq + 1).toLowerCase().replaceAll('0x', '');
    if (hex.length.isOdd || !RegExp(r'^[0-9a-f]*$').hasMatch(hex)) {
      throw FormatException('Invalid hex value in "$part"');
    }
    parsed[id] = [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
  }
  return MbbCommand(
    byte(service, 'service id'),
    byte(command, 'command id'),
    parsed,
  );
}

/// Plain-text report for copy & paste
String mbbDiagnosticsReport(
  Map<String, String> deviceInfo,
  List<MbbTraceEntry> trace,
) {
  final b = StringBuffer('# FreeClip Buddy diagnostics\n');
  for (final e in deviceInfo.entries) {
    b.writeln('${e.key}: ${e.value}');
  }
  b.writeln('\n# Traffic (oldest first)');
  for (final e in trace) {
    b.writeln('$e | ${e.payloadHex}');
  }
  return b.toString();
}
