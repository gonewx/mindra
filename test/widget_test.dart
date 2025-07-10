import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/main.dart';
import 'package:mindra/core/theme/theme_provider.dart';

void main() {
  testWidgets('Mindra app starts correctly', (WidgetTester tester) async {
    // Initialize theme provider
    final themeProvider = ThemeProvider();
    await themeProvider.initialize();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(MindraApp(themeProvider: themeProvider));

    // Wait for a few frames to let the splash page initialize
    await tester.pump();
    
    // Verify that the app starts with splash page
    expect(find.text('Mindra'), findsOneWidget);
    expect(find.text('开启你的冥想之旅'), findsOneWidget);
  });
}
