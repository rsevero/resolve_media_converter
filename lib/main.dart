import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'services/conversion_log_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(const ConversionLogService().deleteAllLogs());

  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1200, 1100),
      minimumSize: Size(1200, 800),
      center: true,
      title: 'Resolve Media Converter',
    );

    final iconPath = p.join(
      p.dirname(Platform.resolvedExecutable),
      'data',
      'flutter_assets',
      'assets',
      'icons',
      'resolve_media_converter-256.png',
    );
    if (File(iconPath).existsSync()) {
      unawaited(windowManager.setIcon(iconPath));
    }

    unawaited(
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  runApp(const ResolveMediaConverterApp());
}
