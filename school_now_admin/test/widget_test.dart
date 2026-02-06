// Widget test for SchoolNow admin panel

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_now_admin/main.dart';

void main() {
  testWidgets('Admin app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Verify app initializes without crashes
    expect(find.byType(MyApp), findsOneWidget);
  });
}
