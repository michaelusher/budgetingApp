import 'package:flutter_test/flutter_test.dart';
import 'package:budget_buddy/main.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}