import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fan_app/main.dart';

void main() {
  testWidgets('TranslateView renders title smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Verify that the title is rendered.
    expect(find.text('Gemma 4 Live Translate'), findsOneWidget);
  });
}
