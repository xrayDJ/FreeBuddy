import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../headphones/framework/headphones_settings.dart';
import '../../../headphones/huawei/settings.dart';
import '../../common/headphones_connection_ensuring_overlay.dart';
import 'huawei/freeclip2_settings.dart';

class HeadphonesSettingsPage extends StatelessWidget {
  const HeadphonesSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.pageHeadphonesSettingsTitle)),
      body: Center(
        child: HeadphonesConnectionEnsuringOverlay(
          builder: (_, h) => ListView(
            children: freeClip2SettingsWidgets(
              h as HeadphonesSettings<HuaweiFreeClip2Settings>,
            ),
          ),
        ),
      ),
    );
  }
}
