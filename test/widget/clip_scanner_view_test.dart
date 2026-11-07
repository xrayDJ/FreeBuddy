import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freebuddy/headphones/huawei/ble_finder.dart';
import 'package:freebuddy/ui/pages/find_clip/clip_scanner_view.dart';

void main() {
  late StreamController<BleSighting> scan;

  setUp(() => scan = StreamController<BleSighting>.broadcast());
  tearDown(() => scan.close());

  Future<void> open(
    WidgetTester tester, {
    bool permission = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: ClipScannerView(
          scan: () => scan.stream,
          bondedClips: () async => ['AA:BB:CC:DD:EE:01'],
          requestPermissions: () async => permission,
          locationServiceOn: () async => true,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  // the view redraws on a timer: unmount to stop it before the test ends
  Future<void> close(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  BleSighting s(String address, int rssi, {int? company}) => BleSighting(
        time: DateTime.now(),
        address: address,
        rssi: rssi,
        manufacturerData: {if (company != null) company: Uint8List(2)},
      );

  testWidgets("Shows your clip as the target, hides non-Huawei by default",
      (tester) async {
    await open(tester);
    expect(find.textContaining('No Huawei signal yet'), findsOneWidget);

    scan
      ..add(s('AA:BB:CC:DD:EE:01', -60))
      ..add(s('22:22:22:22:22:22', -50, company: 0x027D))
      ..add(s('11:11:11:11:11:11', -40, company: 0x004C));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Hot'), findsOneWidget); // -60 dBm
    expect(find.textContaining('Your clip'), findsWidgets);
    expect(find.text('Signals heard (2)'), findsOneWidget);
    expect(find.text('11:11:11:11:11:11'), findsNothing);

    await tester.tap(find.text('Show all Bluetooth devices'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Signals heard (3)'), findsOneWidget);
    await close(tester);
  });

  testWidgets("Tapping a signal follows it", (tester) async {
    await open(tester);
    scan
      ..add(s('AA:BB:CC:DD:EE:01', -90))
      ..add(s('22:22:22:22:22:22', -50, company: 0x027D));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cold'), findsOneWidget); // own clip first, far away

    await tester.tap(find.text('22:22:22:22:22:22').last);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Very close'), findsOneWidget);
    await close(tester);
  });

  testWidgets("No permission: explains and offers to grant", (tester) async {
    await open(tester, permission: false);
    expect(find.text('Grant'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    await close(tester);
  });

  testWidgets("Bluetooth off is reported", (tester) async {
    await open(tester);
    scan.addError(PlatformException(code: 'BT_OFF'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Bluetooth is off'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await close(tester);
  });
}
