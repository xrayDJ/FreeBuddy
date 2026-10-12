import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FreebuddyIntroduction extends StatelessWidget {
  const FreebuddyIntroduction({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tt = t.textTheme;
    final l = AppLocalizations.of(context)!;

    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: t.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(child: Text(text, style: tt.bodyLarge)),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/app_icons/ic_launcher.png',
                    width: 112,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l.pageIntroTitle,
                style: tt.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              point(Icons.battery_charging_full, l.pageIntroWhatIsThis),
              point(Icons.lock_outline, l.pageIntroPrivacy),
              point(Icons.lightbulb_outline, l.pageIntroTip),
              const Spacer(flex: 4),
              FilledButton(
                onPressed: () => Navigator.of(context).pop<bool>(true),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l.pageIntroQuit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
