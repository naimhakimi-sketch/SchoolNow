// Widget test for SchoolNow driver application

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_now_driver/features/auth/login_page.dart';

void main() {
  testWidgets('Driver login smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('Driver Login'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // email + password
  });
}
