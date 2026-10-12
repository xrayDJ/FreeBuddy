import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freebuddy/version.dart';

void main() {
  test("appVersion matches pubspec.yaml", () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version: *(\S+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    expect(appVersion, version);
  });
}
