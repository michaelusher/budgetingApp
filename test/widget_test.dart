import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_buddy/main.dart';

void main() {
  testWidgets('App renders onboarding screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    // First frame shows the loading state; pump until the async state load
    // completes and onboarding appears.
    await tester.pump();
    await tester.pump();
    expect(find.text('Budget Buddy'), findsOneWidget);
  });
}
