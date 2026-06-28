import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:goodo/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GoOdoApp()));
    await tester.pumpAndSettle();

    // Should show login screen initially
    expect(find.text('GoOdo'), findsOneWidget);
  });
}
