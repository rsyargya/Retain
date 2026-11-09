import 'package:flutter_test/flutter_test.dart';
import 'package:retain_mobile/main.dart';

void main() {
  testWidgets('shows dashboard title', (WidgetTester tester) async {
    await tester.pumpWidget(const RetainApp());
    expect(find.text('Retain Monitor'), findsOneWidget);
  });
}
