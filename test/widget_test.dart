import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_hub/core/constants/app_icons.dart';

void main() {
  test('app icon constants are available', () {
    expect(AppIcons.home, isA<IconData>());
    expect(AppIcons.movie, isA<IconData>());
    expect(AppIcons.notification, isA<IconData>());
  });
}
