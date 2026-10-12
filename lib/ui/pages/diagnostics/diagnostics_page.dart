import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../headphones/huawei/mbb_diagnostics.dart';
import '../../common/headphones_connection_ensuring_overlay.dart';

/// Raw MBB traffic + a way to send any command - for figuring out what the
/// FreeClip 2 really does with gesture and settings commands
class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.diagnosticsTitle)),
      body: Center(
        child: HeadphonesConnectionEnsuringOverlay(
          builder: (_, h) => switch (h) {
            MbbDiagnostics d => _DiagnosticsBody(d),
            _ => const SizedBox(),
          },
        ),
      ),
    );
  }
}

const _mono = TextStyle(fontFamily: 'monospace', fontSize: 12);

class _DiagnosticsBody extends StatefulWidget {
  final MbbDiagnostics d;

  const _DiagnosticsBody(this.d);

  @override
  State<_DiagnosticsBody> createState() => _DiagnosticsBodyState();
}

class _DiagnosticsBodyState extends State<_DiagnosticsBody> {
  // pre-filled with "read triple tap" - the thing we are debugging
  final _service = TextEditingController(text: '0x01');
  final _command = TextEditingController(text: '0x26');
  final _args = TextEditingController(text: '1= 2=');

  @override
  void dispose() {
    _service.dispose();
    _command.dispose();
    _args.dispose();
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _copy(String text) async {
    final l = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: text));
    _snack(l.diagnosticsCopied);
  }

  void _send() {
    try {
      final cmd = parseMbbCommandSpec(_service.text, _command.text, _args.text);
      widget.d.sendRaw(cmd);
    } on FormatException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = Theme.of(context);
    final d = widget.d;
    return StreamBuilder<List<MbbTraceEntry>>(
      stream: d.mbbTrace,
      builder: (_, traceSnap) {
        final trace = traceSnap.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.copy),
                  label: Text(l.diagnosticsCopy),
                  onPressed: () => _copy(mbbDiagnosticsReport(
                    d.deviceInfo.valueOrNull ?? const {},
                    trace,
                  )),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(l.diagnosticsReread),
                  onPressed: d.rereadAll,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: StreamBuilder<Map<String, String>>(
                stream: d.deviceInfo,
                builder: (_, snap) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.diagnosticsDeviceInfo,
                          style: t.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (snap.data?.isEmpty ?? true)
                        Text(l.diagnosticsNoInfo)
                      else
                        for (final e in snap.data!.entries)
                          SelectableText('${e.key}: ${e.value}'),
                    ],
                  ),
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.diagnosticsSend, style: t.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(l.diagnosticsSendDesc, style: t.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _service,
                            decoration: InputDecoration(
                              labelText: l.diagnosticsService,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _command,
                            decoration: InputDecoration(
                              labelText: l.diagnosticsCommand,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _args,
                      style: _mono,
                      decoration: InputDecoration(
                        labelText: l.diagnosticsParams,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.send),
                        label: Text(l.diagnosticsSendBtn),
                        onPressed: _send,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text(
                l.diagnosticsTraffic(trace.length),
                style: t.textTheme.titleSmall!
                    .copyWith(color: t.colorScheme.primary),
              ),
            ),
            if (trace.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.diagnosticsEmpty),
              ),
            // newest first
            for (final e in trace.reversed) _TraceTile(e, onTap: _copy),
          ],
        );
      },
    );
  }
}

class _TraceTile extends StatelessWidget {
  final MbbTraceEntry e;
  final void Function(String) onTap;

  const _TraceTile(this.e, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        e.outgoing ? Icons.north_east : Icons.south_west,
        color: e.outgoing ? cs.primary : cs.tertiary,
        semanticLabel: e.outgoing ? 'TX' : 'RX',
      ),
      title: Text('${e.idLabel}  ${e.argsLabel}', style: _mono),
      subtitle: Text(
        [
          e.timeLabel,
          '(${e.command.serviceId},${e.command.commandId})',
          if (e.isWriteReply) l.diagnosticsWriteReply,
        ].join(' · '),
      ),
      onTap: () => onTap('$e | ${e.payloadHex}'),
    );
  }
}
