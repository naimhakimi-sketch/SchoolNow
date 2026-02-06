// Widget test for SchoolNow parent application

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SchoolNow smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('SchoolNow'))),
      ),
    );

    expect(find.text('SchoolNow'), findsOneWidget);
  });
}
