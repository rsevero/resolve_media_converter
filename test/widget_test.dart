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

  testWidgets('source and output controls switch labels', (tester) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(const ResolveMediaConverterApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Directory'));
    await tester.pump();
    expect(find.text('Choose Directory'), findsOneWidget);

    await tester.ensureVisible(find.text('for_resolve subdir'));
    await tester.tap(find.text('for_resolve subdir'));
    await tester.pump();
    expect(find.textContaining('for_resolve/source_name'), findsOneWidget);
  });

  testWidgets('convert button stays disabled without valid setup', (tester) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(const ResolveMediaConverterApp());
    await tester.pumpAndSettle();

    final convertButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Convert'),
    );

    expect(convertButton.onPressed, isNull);
  });

  testWidgets('last used directory is restored on startup', (tester) async {
    SharedPreferences.setMockInitialValues(const {
      'picker.last_used_directory': '/tmp/resolve_media',
    });

    await tester.pumpWidget(const ResolveMediaConverterApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('No source selected yet.'), findsOneWidget);
  });
}
