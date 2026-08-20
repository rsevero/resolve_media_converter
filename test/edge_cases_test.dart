import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resolve_media_converter/features/conversion/application/conversion_setup_controller.dart';
import 'package:resolve_media_converter/models/conversion_enums.dart';
import 'package:resolve_media_converter/models/tool_paths_settings.dart';
import 'package:resolve_media_converter/services/output_path_service.dart';
import 'package:resolve_media_converter/services/trim_parser_service.dart';

void main() {
  group('TrimParserService', () {
    const service = TrimParserService();

    test('accepts seconds-only input', () {
      final result = service.parse('45');
      expect(result.isValid, isTrue);
      expect(result.duration, const Duration(seconds: 45));
    });

    test('accepts millisecond precision', () {
      final result = service.parse('00:01:02.5');
      expect(result.isValid, isTrue);
      expect(result.duration, const Duration(minutes: 1, seconds: 2, milliseconds: 500));
    });

    test('rejects malformed time values', () {
      expect(service.parse('00::10').errorMessage, isNotNull);
      expect(service.parse('aa:10').errorMessage, isNotNull);
      expect(service.parse('00:10.1234').errorMessage, isNotNull);
      expect(service.parse('10:99').errorMessage, isNotNull);
    });
  });

  group('ConversionSetupController', () {
    test('resetTrimValues clears trim text and validation errors', () {
      final controller = ConversionSetupController();

      controller.updateStartTimeText('00:00:10');
      controller.updateEndTimeText('00:00:05');

      expect(controller.startTimeText, '00:00:10');
      expect(controller.endTimeText, '00:00:05');
      expect(controller.endTimeError, 'End time must be greater than start time.');

      controller.resetTrimValues();

      expect(controller.startTimeText, isEmpty);
      expect(controller.endTimeText, isEmpty);
      expect(controller.startTimeError, isNull);
      expect(controller.endTimeError, isNull);
      expect(controller.hasValidTrimRange, isTrue);
    });

    test('buildRequest uses full conversion after trim reset', () {
      final controller = ConversionSetupController();

      controller.setSelectedSourcePath('/tmp/source.mov');
      controller.updateStartTimeText('00:00:03');
      controller.updateEndTimeText('00:00:09');
      controller.resetTrimValues();

      final request = controller.buildRequest(
        ffmpegPath: '/usr/bin/ffmpeg',
        ffprobePath: '/usr/bin/ffprobe',
      );

      expect(request, isNotNull);
      expect(request!.startTime, isNull);
      expect(request.endTime, isNull);
    });

    test('duration is combined with start time to derive end time', () {
      final controller = ConversionSetupController();

      controller.setSelectedSourcePath('/tmp/source.mov');
      controller.updateStartTimeText('00:00:10');
      controller.updateDurationText('00:00:05');

      expect(controller.hasValidTrimRange, isTrue);

      final request = controller.buildRequest(
        ffmpegPath: '/usr/bin/ffmpeg',
        ffprobePath: '/usr/bin/ffprobe',
      );

      expect(request, isNotNull);
      expect(request!.startTime, const Duration(seconds: 10));
      expect(request.endTime, const Duration(seconds: 15));
    });

    test('setting both end time and duration is rejected', () {
      final controller = ConversionSetupController();

      controller.updateEndTimeText('00:00:10');
      controller.updateDurationText('00:00:05');

      expect(controller.hasValidTrimRange, isFalse);
      expect(controller.endTimeError, isNotNull);
      expect(controller.durationError, isNotNull);
    });
  });

  group('ToolPathsSettings', () {
    test('manual overrides take precedence over detected paths', () {
      const settings = ToolPathsSettings(
        manualFfmpegPath: ' /custom/ffmpeg ',
        manualFfprobePath: '/custom/ffprobe',
      );

      expect(settings.effectiveFfmpegPath('/usr/bin/ffmpeg'), '/custom/ffmpeg');
      expect(settings.effectiveFfprobePath('/usr/bin/ffprobe'), '/custom/ffprobe');
    });

    test('blank manual overrides fall back to detected paths', () {
      const settings = ToolPathsSettings(
        manualFfmpegPath: '   ',
        manualFfprobePath: '',
      );

      expect(settings.effectiveFfmpegPath('/usr/bin/ffmpeg'), '/usr/bin/ffmpeg');
      expect(settings.effectiveFfprobePath('/usr/bin/ffprobe'), '/usr/bin/ffprobe');
    });
  });

  group('OutputPathService', () {
    test('adds numeric suffix when destination already exists', () async {
      final tempDir = await Directory.systemTemp.createTemp('resolve-output');
      addTearDown(() => tempDir.delete(recursive: true));

      final sourcePath = '${tempDir.path}/clip.wav';
      await File(sourcePath).writeAsString('source');
      await File('${tempDir.path}/clip-for_resolve.wav').writeAsString('existing');

      final destination = await const OutputPathService().buildDestinationPath(
        sourcePath: sourcePath,
        mediaKind: MediaKind.audio,
        outputMode: OutputMode.sameFolderSuffix,
      );

      expect(destination, '${tempDir.path}/clip-for_resolve-1.wav');
    });

    test('includes trim times in subdir output name', () async {
      final tempDir = await Directory.systemTemp.createTemp('resolve-subdir-trim');
      addTearDown(() => tempDir.delete(recursive: true));

      final destination = await const OutputPathService().buildDestinationPath(
        sourcePath: '${tempDir.path}/clip.mov',
        mediaKind: MediaKind.video,
        outputMode: OutputMode.resolveSubdirectory,
        startTime: const Duration(minutes: 1, seconds: 2),
        endTime: const Duration(minutes: 3, seconds: 4, milliseconds: 250),
      );

      expect(
        destination,
        '${tempDir.path}/for_resolve/clip-trim-00h01m02s000ms-to-00h03m04s250ms.mxf',
      );
    });

    test('creates for_resolve directory for subdir mode', () async {
      final tempDir = await Directory.systemTemp.createTemp('resolve-subdir');
      addTearDown(() => tempDir.delete(recursive: true));

      final destination = await const OutputPathService().buildDestinationPath(
        sourcePath: '${tempDir.path}/clip.mov',
        mediaKind: MediaKind.video,
        outputMode: OutputMode.resolveSubdirectory,
      );

      expect(destination, '${tempDir.path}/for_resolve/clip.mxf');
      expect(Directory('${tempDir.path}/for_resolve').existsSync(), isTrue);
    });
  });
}
