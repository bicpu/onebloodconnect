// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/create_account.dart';
import 'package:my_first_app/home.dart';
import 'package:my_first_app/main.dart';

void main() {
  testWidgets('sign-in screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Initializing application...'), findsOneWidget);
    expect(find.text('Proceed to Sign In'), findsOneWidget);
  });

  testWidgets('sign-in validates empty credentials', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignInPage()));

    await tester.ensureVisible(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();

    expect(find.text('Enter email and password.'), findsOneWidget);
  });

  testWidgets('create account screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateAccountPage()));

    expect(find.text('One Blood Connect'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
