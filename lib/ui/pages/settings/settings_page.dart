import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(l.diagnosticsTitle),
            subtitle: Text(l.diagnosticsDesc),
            onTap: () =>
                Navigator.of(context).pushNamed('/settings/diagnostics'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.pageAboutTitle),
            onTap: () => Navigator.of(context).pushNamed('/settings/about'),
          ),
        ],
      ),
    );
  }
}
