import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linklocker_app/screens/auth_screen.dart';

void main() {
  testWidgets('AuthScreen renders Sign In / Sign Up button', (WidgetTester tester) async {
    // Mount just the AuthScreen to avoid coupling tests to the app root class name.
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

    // Verify primary action is present.
    expect(find.text('Sign In / Sign Up'), findsOneWidget);
  });
}