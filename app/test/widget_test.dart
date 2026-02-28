import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperdrop/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PaperDropApp()));
    // PaperDrop title should appear in the AppBar
    expect(find.text('PaperDrop'), findsOneWidget);
  });
}
