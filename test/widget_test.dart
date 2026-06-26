import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resolve_file_converter/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app shell renders workflow controls', (tester) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(const ResolveMediaConverterApp());
    await tester.pumpAndSettle();

    expect(find.text('Resolve Media Converter'), findsWidgets);
    expect(find.text('Tool paths'), findsOneWidget);
    expect(find.text('Source selection'), findsOneWidget);
    expect(find.text('Output placement'), findsOneWidget);
    expect(find.text('Trim controls'), findsOneWidget);
    expect(find.text('FFmpeg'), findsOneWidget);
    expect(find.text('FFprobe'), findsOneWidget);
  });

  testWidgets('trim validation rejects end time before start time', (tester) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(const ResolveMediaConverterApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Start time'), '00:00:10');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'End time'), '00:00:05');
    await tester.pump();

    expect(find.text('End time must be greater than start time.'), findsOneWidget);
  });
}
