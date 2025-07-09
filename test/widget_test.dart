// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindra/main.dart';

void main() {
  testWidgets('Mindra app starts correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MindraApp());

    // Wait for a few frames to let the splash page initialize
    await tester.pump();
    
    // Verify that the app starts with splash page
    expect(find.text('Mindra'), findsOneWidget);
    expect(find.text('开启你的冥想之旅'), findsOneWidget);
  });
}
