import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../version.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _forkUrl = 'https://github.com/xrayDJ/FreeBuddy';
  static const _freeBuddyUrl = 'https://github.com/TheLastGimbus/FreeBuddy';
  static const _openFreebudsUrl = 'https://github.com/melianmiko/OpenFreebuds';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = Theme.of(context);
    final tt = t.textTheme;

    Widget link(IconData icon, String title, String url, {String? subtitle}) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle ?? url),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () =>
              launchUrlString(url, mode: LaunchMode.externalApplication),
        );

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Text(
            text,
            style: tt.titleSmall!.copyWith(color: t.colorScheme.primary),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.pageAboutTitle)),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/app_icons/ic_launcher.png', width: 96),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(l.appTitle, style: tt.headlineMedium)),
          Center(
            child: Text(
              l.pageAboutVersion(appVersion),
              style: tt.bodyMedium!
                  .copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.pageAboutIntro, textAlign: TextAlign.center),
          ),
          link(Icons.code, l.pageAboutSource, _forkUrl),
          header(l.pageAboutCredits),
          link(Icons.headphones_outlined, 'FreeBuddy', _freeBuddyUrl,
              subtitle: l.pageAboutCreditsFreeBuddy),
          link(Icons.cable, 'OpenFreebuds', _openFreebudsUrl,
              subtitle: l.pageAboutCreditsOpenFreebuds),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.pageAboutLicense, style: tt.bodySmall),
          ),
          header(l.privacyPolicyTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.privacyPolicyText),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l.pageAboutOpenSourceLicensesBtn),
            onTap: () =>
                Navigator.of(context).pushNamed('/settings/about/licenses'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
