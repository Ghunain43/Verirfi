import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifi/home_page.dart';

void main() {
  testWidgets('Home shows the headline and both actions', (
    WidgetTester tester,
  ) async {
    var checkTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(onCheck: () => checkTapped = true, onRadar: () {}),
        ),
      ),
    );
    // Not pumpAndSettle: the logo and particles animate forever.
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Check it before'), findsOneWidget);
    expect(find.text('Check a claim'), findsOneWidget);
    expect(find.text('Rumor Radar'), findsWidgets);

    await tester.tap(find.text('Check a claim'));
    expect(checkTapped, isTrue);
  });
}
