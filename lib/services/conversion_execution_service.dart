import 'dart:io';

import '../models/conversion_enums.dart';
import '../models/conversion_result.dart';
import '../models/resolved_job.dart';

class ConversionExecutionService {
  const ConversionExecutionService();

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

      if (result.exitCode == 0) {
        return ConversionResult(
          sourcePath: job.sourcePath,
          destinationPath: job.destinationPath,
          status: ConversionStatus.success,
          mediaKind: job.mediaKind,
          elapsed: stopwatch.elapsed,
        );
      }

      return ConversionResult(
        sourcePath: job.sourcePath,
        destinationPath: job.destinationPath,
        status: ConversionStatus.failed,
        mediaKind: job.mediaKind,
        errorMessage: _firstLine(result.stderr) ?? 'ffmpeg failed.',
        elapsed: stopwatch.elapsed,
      );
    } on ProcessException catch (error) {
      stopwatch.stop();
      return ConversionResult(
        sourcePath: job.sourcePath,
        destinationPath: job.destinationPath,
        status: ConversionStatus.failed,
        mediaKind: job.mediaKind,
        errorMessage: error.message,
        elapsed: stopwatch.elapsed,
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
