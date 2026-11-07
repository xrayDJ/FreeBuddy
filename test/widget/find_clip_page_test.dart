import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freebuddy/cubit/headphones_connection_cubit.dart';
import 'package:freebuddy/cubit/headphones_cubit_objects.dart';
import 'package:freebuddy/cubit/headphones_mock_cubit.dart';
import 'package:freebuddy/headphones/huawei/freeclip2/freeclip2_sim.dart';
import 'package:freebuddy/platform_stuff/android/find_clip.dart';
import 'package:freebuddy/ui/pages/find_clip/find_clip_page.dart';

/// Mock cubit (connected FreeClip 2 simulator) whose state tests can change
class _TestCubit extends HeadphonesMockCubit {
  void set(HeadphonesConnectionState s) => emit(s);

  HuaweiFreeClip2Sim get sim =>
      (state as HeadphonesConnectedOpen).headphones as HuaweiFreeClip2Sim;
}

void main() {
  late List<String> calls;
  late Future<Object?> Function(MethodCall) handler;

  setUp(() {
    calls = [];
    handler = (call) async {
      calls.add(call.method);
      return null;
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(FindClip.channel, (c) => handler(c));
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(FindClip.channel, null));

  Future<_TestCubit> open(WidgetTester tester) async {
    // small phone (360x640): the main button must be on screen anyway
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final cubit = _TestCubit();
    await tester.pumpWidget(BlocProvider<HeadphonesConnectionCubit>.value(
      value: cubit,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        // the real scanner needs the platform; tested on its own
        home: FindClipPage(scanner: SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();
    // opened while still "connecting": the page starts on the scanner tab
    await tester.tap(find.text('Ring'));
    await tester.pumpAndSettle();
    return cubit;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    // no scrolling: tap fails if the button is off screen
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets("Start beeps with auto pause off, stop restores it",
      (tester) async {
    final cubit = await open(tester);
    expect(cubit.sim.settings.value.autoPause, true);

    await tap(tester, 'Play sound');
    expect(calls, ['start']);
    expect(cubit.sim.settings.value.autoPause, false);

    await tap(tester, 'Stop');
    expect(calls, ['start', 'stop']);
    expect(cubit.sim.settings.value.autoPause, true);
    expect(find.text('Play sound'), findsOneWidget);
  });

  testWidgets("Losing the connection stops the beep", (tester) async {
    final cubit = await open(tester);
    await tap(tester, 'Play sound');

    cubit.set(const HeadphonesDisconnected(HuaweiFreeClip2SimPlaceholder()));
    await tester.pumpAndSettle();
    expect(calls, ['start', 'stop']);
    expect(find.textContaining('Connection lost'), findsOneWidget);
  });

  testWidgets("Platform error: message, auto pause restored", (tester) async {
    handler = (call) async => throw PlatformException(code: 'TONE_FAILED');
    final cubit = await open(tester);

    await tap(tester, 'Play sound');
    expect(find.text("Couldn't play the sound"), findsOneWidget);
    expect(cubit.sim.settings.value.autoPause, true);
    expect(find.text('Play sound'), findsOneWidget);
  });
}
