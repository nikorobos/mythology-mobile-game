import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theomyth/main.dart';

void main() {
  testWidgets('splash shows the logo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TheomythApp());
    expect(find.text('THEO'), findsOneWidget);
    expect(find.text('MYTH'), findsOneWidget);
    // Let the splash finish so no timer or ticker is left running.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  });
}
