import 'dart:io';

import '../models/conversion_enums.dart';
import '../models/conversion_result.dart';
import '../models/resolved_job.dart';
import 'conversion_log_service.dart';

class ConversionExecutionService {
  const ConversionExecutionService({
    ConversionLogService? conversionLogService,
  }) : _conversionLogService = conversionLogService ?? const ConversionLogService();

  final ConversionLogService _conversionLogService;

  Future<ConversionResult> execute({
    required String ffmpegPath,
    required ResolvedJob job,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await Process.run(
        ffmpegPath,
        job.arguments,
        runInShell: Platform.isWindows,
      );
      stopwatch.stop();
      final logFilePath = await _conversionLogService.writeLog(
        sourcePath: job.sourcePath,
        destinationPath: job.destinationPath,
        status:
            result.exitCode == 0
                ? ConversionStatus.success
                : ConversionStatus.failed,
        mediaKind: job.mediaKind,
        ffmpegPath: ffmpegPath,
        arguments: job.arguments,
        exitCode: result.exitCode,
        stdoutOutput: result.stdout.toString(),
        stderrOutput: result.stderr.toString(),
        errorMessage:
            result.exitCode == 0 ? null : _firstLine(result.stderr) ?? 'ffmpeg failed.',
      );

      if (result.exitCode == 0) {
        return ConversionResult(
          sourcePath: job.sourcePath,
          destinationPath: job.destinationPath,
          status: ConversionStatus.success,
          mediaKind: job.mediaKind,
          elapsed: stopwatch.elapsed,
          logFilePath: logFilePath,
        );
      }

      return ConversionResult(
        sourcePath: job.sourcePath,
        destinationPath: job.destinationPath,
        status: ConversionStatus.failed,
        mediaKind: job.mediaKind,
        errorMessage: _firstLine(result.stderr) ?? 'ffmpeg failed.',
        elapsed: stopwatch.elapsed,
        logFilePath: logFilePath,
      );
    } on ProcessException catch (error) {
      stopwatch.stop();
      final logFilePath = await _conversionLogService.writeLog(
        sourcePath: job.sourcePath,
        destinationPath: job.destinationPath,
        status: ConversionStatus.failed,
        mediaKind: job.mediaKind,
        ffmpegPath: ffmpegPath,
        arguments: job.arguments,
        errorMessage: error.message,
        note: 'ffmpeg could not be started.',
      );
      return ConversionResult(
        sourcePath: job.sourcePath,
        destinationPath: job.destinationPath,
        status: ConversionStatus.failed,
        mediaKind: job.mediaKind,
        errorMessage: error.message,
        elapsed: stopwatch.elapsed,
        logFilePath: logFilePath,
      );
    }
  }

  String? _firstLine(Object? value) {
    final lines = value
        .toString()
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    return lines.isEmpty ? null : lines.first;
  }
}
