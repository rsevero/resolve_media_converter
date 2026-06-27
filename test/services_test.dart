import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resolve_file_converter/models/conversion_enums.dart';
import 'package:resolve_file_converter/models/conversion_request.dart';
import 'package:resolve_file_converter/services/conversion_log_service.dart';
import 'package:resolve_file_converter/services/ffmpeg_command_service.dart';
import 'package:resolve_file_converter/services/media_probe_service.dart';
import 'package:resolve_file_converter/services/output_path_service.dart';
import 'package:resolve_file_converter/services/source_resolution_service.dart';

void main() {
  group('SourceResolutionService', () {
    test('scans only top-level files in a directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('resolve-scan');
      addTearDown(() => tempDir.delete(recursive: true));
      await File('${tempDir.path}/clip.mov').writeAsString('a');
      await Directory('${tempDir.path}/nested').create();
      await File('${tempDir.path}/nested/inside.mov').writeAsString('b');

      final result = await const SourceResolutionService().resolve(
        sourcePath: tempDir.path,
        sourceType: SourceType.directory,
      );

      expect(result.candidatePaths, hasLength(1));
      expect(result.candidatePaths.single, endsWith('clip.mov'));
      expect(result.skippedPaths.single, endsWith('nested'));
    });
  });

  group('MediaProbeService', () {
    test('classifies probe output with video stream as video', () {
      const json = '''
      {"streams":[{"codec_type":"audio"},{"codec_type":"video"}]}
      ''';

      final result = const MediaProbeService().parseProbeOutput(
        sourcePath: '/tmp/clip.mp4',
        jsonOutput: json,
      );

      expect(result.mediaKind, MediaKind.video);
    });
  });

  group('OutputPathService', () {
    test('builds same-folder suffix output for audio', () async {
      final result = await const OutputPathService().buildDestinationPath(
        sourcePath: '/tmp/source.wav',
        mediaKind: MediaKind.audio,
        outputMode: OutputMode.sameFolderSuffix,
      );

      expect(result, '/tmp/source-for_resolve.wav');
    });
  });

  group('FfmpegCommandService', () {
    test('builds audio conversion arguments', () {
      final request = ConversionRequest(
        sourcePath: '/tmp/source.wav',
        sourceType: SourceType.file,
        outputMode: OutputMode.sameFolderSuffix,
        ffmpegPath: 'ffmpeg',
        ffprobePath: 'ffprobe',
        startTime: const Duration(seconds: 5),
        endTime: const Duration(seconds: 12),
      );

      final job = const FfmpegCommandService().buildJob(
        request: request,
        sourcePath: '/tmp/source.wav',
        destinationPath: '/tmp/source-for_resolve.wav',
        mediaKind: MediaKind.audio,
      );

      expect(job.arguments, containsAllInOrder(['-ss', '00:00:05.000']));
      expect(job.arguments, containsAllInOrder(['-to', '00:00:12.000']));
      expect(job.arguments, containsAllInOrder(['-c:a', 'pcm_s24le']));
      expect(job.arguments.last, '/tmp/source-for_resolve.wav');
    });

    test('builds video conversion arguments', () {
      final request = ConversionRequest(
        sourcePath: '/tmp/source.mov',
        sourceType: SourceType.file,
        outputMode: OutputMode.sameFolderSuffix,
        ffmpegPath: 'ffmpeg',
        ffprobePath: 'ffprobe',
      );

      final job = const FfmpegCommandService().buildJob(
        request: request,
        sourcePath: '/tmp/source.mov',
        destinationPath: '/tmp/source-for_resolve.mov',
        mediaKind: MediaKind.video,
      );

      expect(job.arguments, containsAllInOrder(['-c:v', 'dnxhd']));
      expect(job.arguments, containsAllInOrder(['-profile:v', 'dnxhr_hq']));
      expect(job.arguments.last, '/tmp/source-for_resolve.mov');
    });
  });

  group('ConversionLogService', () {
    test('writes a persistent log file with command output', () async {
      final tempDir = await Directory.systemTemp.createTemp('resolve-logs');
      addTearDown(() => tempDir.delete(recursive: true));
      final service = ConversionLogService(rootDirectoryPath: tempDir.path);

      final logFilePath = await service.writeLog(
        sourcePath: '/tmp/source.mov',
        destinationPath: '/tmp/source-for_resolve.mov',
        status: ConversionStatus.success,
        mediaKind: MediaKind.video,
        ffmpegPath: '/usr/bin/ffmpeg',
        arguments: const ['-i', '/tmp/source.mov', '/tmp/source-for_resolve.mov'],
        exitCode: 0,
        stdoutOutput: 'frame=100',
        stderrOutput: 'ffmpeg banner',
      );

      expect(logFilePath, isNotNull);

      final content = await File(logFilePath!).readAsString();
      expect(content, contains('Status: success'));
      expect(content, contains('FFmpeg: /usr/bin/ffmpeg'));
      expect(content, contains('frame=100'));
      expect(content, contains('ffmpeg banner'));
      expect(File(logFilePath).existsSync(), isTrue);
    });
  });
}
