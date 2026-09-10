import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:urbanex/main.dart';

void main() {
  testWidgets('App launches and shows onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const UrbanExApp());

    // First frame shows a loading spinner while SharedPreferences loads.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let async bootstrap (SharedPreferences) settle.
    await tester.pumpAndSettle();

    // A fresh install has not onboarded yet, so the onboarding screen
    // should be showing its heading.
    expect(find.text('What best describes you?'), findsOneWidget);
  });
}
