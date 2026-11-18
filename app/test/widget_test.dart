import 'package:flutter_test/flutter_test.dart';
import 'package:lingowander/main.dart';

void main() {
  testWidgets('placeholder home shows the product name', (tester) async {
    await tester.pumpWidget(const LingowanderApp());

    expect(find.textContaining('语遇 Lingowander'), findsOneWidget);
    expect(find.textContaining('lingo_core'), findsOneWidget);
    expect(find.textContaining('lingo_protocol'), findsOneWidget);
  });
}
