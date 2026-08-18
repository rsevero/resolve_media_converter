import '../features/conversion/presentation/conversion_shell_page.dart';
import 'package:material_ui/material_ui.dart';

class ResolveMediaConverterApp extends StatelessWidget {
  const ResolveMediaConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A5C6B),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Resolve Media Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4F1EA),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      home: const ConversionShellPage(),
    );
  }
}
