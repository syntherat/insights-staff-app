import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:insights_staff_app/main.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: InsightsStaffApp()),
    );

    expect(find.byType(InsightsStaffApp), findsOneWidget);
  });
}
