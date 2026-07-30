import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const Gift360App(onboardingComplete: true));
    expect(find.byType(Gift360App), findsOneWidget);
  });
}
