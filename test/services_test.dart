import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resolve_file_converter/features/conversion/application/conversion_run_controller.dart';
import 'package:resolve_file_converter/models/conversion_enums.dart';
import 'package:resolve_file_converter/models/conversion_request.dart';
import 'package:resolve_file_converter/models/conversion_result.dart';
import 'package:resolve_file_converter/models/media_probe_result.dart';
import 'package:resolve_file_converter/models/resolved_job.dart';
import 'package:resolve_file_converter/models/source_resolution_result.dart';
import 'package:resolve_file_converter/services/conversion_log_service.dart';
import 'package:resolve_file_converter/services/conversion_execution_service.dart';
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

    test('recognizes accepted H.264 MP4 with constant frame rate', () {
      const json = '''
      {
        "format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2"},
        "streams":[
          {
            "codec_type":"video",
            "codec_name":"h264",
            "avg_frame_rate":"24000/1001",
            "r_frame_rate":"24000/1001"
          },
          {"codec_type":"audio","codec_name":"aac"}
        ]
      }
      ''';

      final result = const MediaProbeService().parseProbeOutput(
        sourcePath: '/tmp/clip.mp4',
        jsonOutput: json,
      );

      expect(result.mediaKind, MediaKind.video);
      expect(result.isAcceptedForResolve, isTrue);
      expect(result.acceptedFormatLabel, 'H.264 MP4 (constant frame rate)');
    });

    test('recognizes accepted 48 kHz / 24-bit WAV', () {
      const json = '''
      {
        "format":{"format_name":"wav"},
        "streams":[
          {
            "codec_type":"audio",
            "codec_name":"pcm_s24le",
            "sample_rate":"48000",
            "bits_per_sample":24
          }
        ]
      }
      ''';

      final result = const MediaProbeService().parseProbeOutput(
        sourcePath: '/tmp/clip.wav',
        jsonOutput: json,
      );

      expect(result.mediaKind, MediaKind.audio);
      expect(result.isAcceptedForResolve, isTrue);
      expect(result.acceptedFormatLabel, '48 kHz / 24-bit WAV/BWF');
    });

    test('reads bit depth from bits_per_raw_sample on video stream', () {
      const json = '''
      {
        "streams":[
          {"codec_type":"video","codec_name":"h264","bits_per_raw_sample":"10"},
          {"codec_type":"audio","codec_name":"aac"}
        ]
      }
      ''';

      final result = const MediaProbeService().parseProbeOutput(
        sourcePath: '/tmp/clip.mp4',
        jsonOutput: json,
      );

      expect(result.bitDepth, 10);
    });

    test('does not accept variable frame rate h264 mp4', () {
      const json = '''
      {
        "format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2"},
        "streams":[
          {
            "codec_type":"video",
            "codec_name":"h264",
            "avg_frame_rate":"24000/1001",
            "r_frame_rate":"30000/1001"
          }
        ]
      }
      ''';

      final result = const MediaProbeService().parseProbeOutput(
        sourcePath: '/tmp/clip.mp4',
        jsonOutput: json,
      );

      expect(result.mediaKind, MediaKind.video);
      expect(result.isAcceptedForResolve, isFalse);
      expect(result.acceptedFormatLabel, isNull);
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

      expect(job.arguments, containsAllInOrder(['-ss', '00:00:05.000', '-i', '/tmp/source.wav', '-ss', '00:00:05.000']));
      expect(job.arguments, containsAllInOrder(['-to', '00:00:12.000']));
      expect(job.arguments, containsAllInOrder(['-c:a', 'pcm_s24le']));
      expect(job.arguments.last, '/tmp/source-for_resolve.wav');
    });

    test('builds 8-bit video conversion arguments with DNxHR HQ / yuv422p', () {
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
        destinationPath: '/tmp/source-for_resolve.mxf',
        mediaKind: MediaKind.video,
        bitDepth: 8,
      );

      expect(job.arguments, containsAllInOrder(['-profile:v', 'dnxhr_hq']));
      expect(job.arguments, containsAllInOrder(['-pix_fmt', 'yuv422p']));
      expect(job.arguments.last, '/tmp/source-for_resolve.mxf');
    });

    test('builds 10-bit video conversion arguments with DNxHR HQX / yuv422p10le', () {
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
        destinationPath: '/tmp/source-for_resolve.mxf',
        mediaKind: MediaKind.video,
        bitDepth: 10,
      );

      expect(job.arguments, containsAllInOrder(['-profile:v', 'dnxhr_hqx']));
      expect(job.arguments, containsAllInOrder(['-pix_fmt', 'yuv422p10le']));
      expect(job.arguments.last, '/tmp/source-for_resolve.mxf');
    });

    test('defaults to 8-bit when bitDepth is null', () {
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
        destinationPath: '/tmp/source-for_resolve.mxf',
        mediaKind: MediaKind.video,
      );

      expect(job.arguments, containsAllInOrder(['-profile:v', 'dnxhr_hq']));
      expect(job.arguments, containsAllInOrder(['-pix_fmt', 'yuv422p']));
    });
  });

  group('ConversionLogService', () {
    test('writes a persistent log file with command output', () async {
      final tempDir = await Directory.systemTemp.createTemp('resolve-logs');
      addTearDown(() => tempDir.delete(recursive: true));
      final service = ConversionLogService(rootDirectoryPath: tempDir.path);

      final logFilePath = await service.writeLog(
        sourcePath: '/tmp/source.mov',
        destinationPath: '/tmp/source-for_resolve.mxf',
        status: ConversionStatus.success,
        mediaKind: MediaKind.video,
        ffmpegPath: '/usr/bin/ffmpeg',
        arguments: const ['-i', '/tmp/source.mov', '/tmp/source-for_resolve.mxf'],
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

    test('deletes all stored log files', () async {
      final tempDir = await Directory.systemTemp.createTemp('resolve-logs-cleanup');
      addTearDown(() => tempDir.delete(recursive: true));
      final service = ConversionLogService(rootDirectoryPath: tempDir.path);

      final firstLogPath = await service.writeLog(
        sourcePath: '/tmp/source-a.mov',
        destinationPath: '/tmp/source-a-for_resolve.mxf',
        status: ConversionStatus.success,
        mediaKind: MediaKind.video,
      );
      final secondLogPath = await service.writeLog(
        sourcePath: '/tmp/source-b.wav',
        destinationPath: '/tmp/source-b-for_resolve.wav',
        status: ConversionStatus.failed,
        mediaKind: MediaKind.audio,
      );

      expect(firstLogPath, isNotNull);
      expect(secondLogPath, isNotNull);

      await service.deleteAllLogs();

      expect(File(firstLogPath!).existsSync(), isFalse);
      expect(File(secondLogPath!).existsSync(), isFalse);
      expect(Directory('${tempDir.path}/logs').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/logs').listSync(), isEmpty);
    });
  });

  group('ConversionRunController', () {
    test('keeps the newest completed result at the top', () async {
      final controller = ConversionRunController(
        sourceResolutionService: _FakeSourceResolutionService(
          const SourceResolutionResult(
            candidatePaths: ['/tmp/alpha.mov', '/tmp/bravo.mov'],
            skippedPaths: [],
          ),
        ),
        mediaProbeService: const _FakeMediaProbeService(),
        outputPathService: const _FakeOutputPathService(),
        ffmpegCommandService: const FfmpegCommandService(),
        conversionExecutionService: const _FakeConversionExecutionService(),
        conversionLogService: const ConversionLogService(rootDirectoryPath: '/tmp'),
      );

      final request = ConversionRequest(
        sourcePath: '/tmp',
        sourceType: SourceType.directory,
        outputMode: OutputMode.sameFolderSuffix,
        ffmpegPath: 'ffmpeg',
        ffprobePath: 'ffprobe',
      );

      await controller.run(request);

      expect(
        controller.results.map((result) => result.sourcePath).toList(),
        ['/tmp/bravo.mov', '/tmp/alpha.mov'],
      );
    });
  });
}

class _FakeSourceResolutionService extends SourceResolutionService {
  const _FakeSourceResolutionService(this.result);

  final SourceResolutionResult result;

  @override
  Future<SourceResolutionResult> resolve({
    required String sourcePath,
    required SourceType sourceType,
  }) async {
    return result;
  }
}

class _FakeMediaProbeService extends MediaProbeService {
  const _FakeMediaProbeService();

  @override
  Future<MediaProbeResult> probe({
    required String ffprobePath,
    required String sourcePath,
  }) async {
    return MediaProbeResult(
      sourcePath: sourcePath,
      mediaKind: MediaKind.video,
    );
  }
}

class _FakeOutputPathService extends OutputPathService {
  const _FakeOutputPathService();

  @override
  Future<String> buildDestinationPath({
    required String sourcePath,
    required MediaKind mediaKind,
    required OutputMode outputMode,
  }) async {
    return '$sourcePath.converted';
  }
}

class _FakeConversionExecutionService extends ConversionExecutionService {
  const _FakeConversionExecutionService();

  @override
  Future<ConversionResult> execute({
    required String ffmpegPath,
    required ResolvedJob job,
  }) async {
    return ConversionResult(
      sourcePath: job.sourcePath,
      destinationPath: job.destinationPath,
      status: ConversionStatus.success,
      mediaKind: job.mediaKind,
    );
  }
}
