import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_system/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('TallyCareApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: TallyCareApp()));
    await tester.pump();

    // Verify that TallyCareApp mounts
    expect(find.byType(TallyCareApp), findsOneWidget);
  });
}
