import 'package:flutter_test/flutter_test.dart';
import 'package:hashhaven/main.dart';

void main() {
  testWidgets('HashHaven app boots its Material shell', (tester) async {
    await tester.pumpWidget(const HashHavenApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
