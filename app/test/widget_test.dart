import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperdrop/screens/login_screen.dart';
import 'package:paperdrop/providers/auth_provider.dart';

void main() {
  testWidgets('LoginScreen renders email and password fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith((_) => AuthNotifier.test())],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    // Verify key UI elements render
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('PaperDrop'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // email + password
  });
}
