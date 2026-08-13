import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/conversion_enums.dart';
import '../models/conversion_progress.dart';
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
    Duration? expectedDuration,
    void Function(ConversionProgress progress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final arguments = <String>['-progress', 'pipe:1', '-nostats', ...job.arguments];

    try {
      final process = await Process.start(
        ffmpegPath,
        arguments,
        runInShell: Platform.isWindows,
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      Duration processed = Duration.zero;
      double? speed;

      final stdoutSubscription = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((line) {
        stdoutBuffer.writeln(line);
        final parsed = _parseProgressLine(line);
        if (parsed == null) {
          return;
        }
        if (parsed.processed != null) {
          processed = parsed.processed!;
        }
        if (parsed.speed != null) {
          speed = parsed.speed;
        }
        onProgress?.call(
          ConversionProgress(
            processed: processed,
            total: expectedDuration,
            speed: speed,
          ),
        );
      });

      final stderrSubscription = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(stderrBuffer.write);

      final exitCode = await process.exitCode;
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      stopwatch.stop();

      final result = _ProcessOutput(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
      );

      final logFilePath = await _conversionLogService.writeLog(
        sourcePath: job.sourcePath,
        destinationPath: job.destinationPath,
        status:
            result.exitCode == 0
                ? ConversionStatus.success
                : ConversionStatus.failed,
        mediaKind: job.mediaKind,
        ffmpegPath: ffmpegPath,
        arguments: arguments,
        exitCode: result.exitCode,
        stdoutOutput: result.stdout,
        stderrOutput: result.stderr,
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

  _ProgressUpdate? _parseProgressLine(String line) {
    final separatorIndex = line.indexOf('=');
    if (separatorIndex == -1) {
      return null;
    }
    final key = line.substring(0, separatorIndex).trim();
    final value = line.substring(separatorIndex + 1).trim();

    switch (key) {
      case 'out_time_us':
      case 'out_time_ms':
        final microseconds = int.tryParse(value);
        if (microseconds == null) {
          return null;
        }
        return _ProgressUpdate(
          processed: Duration(microseconds: microseconds),
        );
      case 'speed':
        final speedText = value.endsWith('x')
            ? value.substring(0, value.length - 1)
            : value;
        final speed = double.tryParse(speedText.trim());
        if (speed == null) {
          return null;
        }
        return _ProgressUpdate(speed: speed);
      default:
        return null;
    }
  }
}

class _ProgressUpdate {
  const _ProgressUpdate({this.processed, this.speed});

  final Duration? processed;
  final double? speed;
}

class _ProcessOutput {
  const _ProcessOutput({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
