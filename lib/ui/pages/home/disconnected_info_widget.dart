import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../cubit/headphones_connection_cubit.dart';
import '../find_clip/find_clip_page.dart';

class DisconnectedInfoWidget extends StatelessWidget {
  const DisconnectedInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = Theme.of(context);
    final tt = t.textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.pageHomeDisconnected,
          style: tt.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          l.pageHomeDisconnectedDesc,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () =>
              context.read<HeadphonesConnectionCubit>().openBluetoothSettings(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              l.pageHomeDisconnectedOpenSettings,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // a lost clip is a disconnected clip: offer the nearby search here
        if (ModalRoute.of(context)?.settings.name != '/find_clip') ...[
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.radar),
            label: Text(l.findClipTabScan),
            onPressed: () => Navigator.pushNamed(
              context,
              '/find_clip',
              arguments: FindClipPage.scanTab,
            ),
          ),
        ],
      ],
    );
  }
}
