import 'package:flutter_test/flutter_test.dart';
import 'package:theomyth/main.dart';

void main() {
  testWidgets('app shows the title', (tester) async {
    await tester.pumpWidget(const TheomythApp());
    expect(find.text('THEOMYTH'), findsOneWidget);
  });
}
