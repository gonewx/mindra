import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/main.dart';

void main() {
  testWidgets('Mindra app starts correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MindraApp());

    // Wait for a few frames to let the app initialize
    await tester.pump();

    // Verify that the app starts without crashing
    expect(find.byType(MindraApp), findsOneWidget);
  });
}
