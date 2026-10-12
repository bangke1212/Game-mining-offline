import 'package:flutter_test/flutter_test.dart';
import 'package:hashhaven/main.dart';

void main() {
  testWidgets('HashHaven renders the factory shell', (tester) async {
    await tester.pumpWidget(const HashHavenApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('HASH'), findsOneWidget);
    expect(find.text('HAVEN'), findsOneWidget);
    expect(find.text('MINE NOW   +240 CREDITS'), findsOneWidget);
  });
}
