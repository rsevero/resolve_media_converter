import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/conversion_enums.dart';

class ConversionLogService {
  const ConversionLogService({this.rootDirectoryPath});

  final String? rootDirectoryPath;

  Future<String?> writeLog({
    required String sourcePath,
    required String destinationPath,
    required ConversionStatus status,
    required MediaKind mediaKind,
    String? ffmpegPath,
    List<String>? arguments,
    int? exitCode,
    String? stdoutOutput,
    String? stderrOutput,
    String? errorMessage,
    String? note,
  }) async {
    try {
      final logsDirectory = await _resolveLogsDirectory();
      final timestamp = DateTime.now();
      final fileName =
          '${_timestampSlug(timestamp)}-${_safeName(path.basenameWithoutExtension(sourcePath))}.log';
      final logFile = File(path.join(logsDirectory.path, fileName));
      final content = _buildContent(
        createdAt: timestamp,
        sourcePath: sourcePath,
        destinationPath: destinationPath,
        status: status,
        mediaKind: mediaKind,
        ffmpegPath: ffmpegPath,
        arguments: arguments,
        exitCode: exitCode,
        stdoutOutput: stdoutOutput,
        stderrOutput: stderrOutput,
        errorMessage: errorMessage,
        note: note,
      );
      await logFile.writeAsString(content);
      return logFile.path;
    } catch (_) {
      return null;
    }
  }

  Future<String> readLog(String logFilePath) {
    return File(logFilePath).readAsString();
  }

  Future<Directory> _resolveLogsDirectory() async {
    final basePath = rootDirectoryPath ?? _defaultRootDirectoryPath();
    final logsDirectory = Directory(path.join(basePath, 'logs'));
    if (!await logsDirectory.exists()) {
      await logsDirectory.create(recursive: true);
    }
    return logsDirectory;
  }

  String _defaultRootDirectoryPath() {
    final environment = Platform.environment;

    if (Platform.isWindows) {
      final basePath =
          environment['APPDATA'] ??
          environment['LOCALAPPDATA'] ??
          environment['USERPROFILE'];
      if (basePath == null || basePath.trim().isEmpty) {
        return path.join(Directory.systemTemp.path, 'resolve_file_converter');
      }
      return path.join(basePath, 'ResolveFileConverter');
    }

    final home = environment['HOME'];
    if (home == null || home.trim().isEmpty) {
      return path.join(Directory.systemTemp.path, 'resolve_file_converter');
    }

    if (Platform.isMacOS) {
      return path.join(
        home,
        'Library',
        'Application Support',
        'ResolveFileConverter',
      );
    }

    final stateHome = environment['XDG_STATE_HOME'];
    if (stateHome != null && stateHome.trim().isNotEmpty) {
      return path.join(stateHome, 'resolve_file_converter');
    }

    return path.join(home, '.local', 'state', 'resolve_file_converter');
  }

  String _buildContent({
    required DateTime createdAt,
    required String sourcePath,
    required String destinationPath,
    required ConversionStatus status,
    required MediaKind mediaKind,
    String? ffmpegPath,
    List<String>? arguments,
    int? exitCode,
    String? stdoutOutput,
    String? stderrOutput,
    String? errorMessage,
    String? note,
  }) {
    final buffer = StringBuffer()
      ..writeln('Resolve Media Converter log')
      ..writeln('Created: ${createdAt.toIso8601String()}')
      ..writeln('Status: ${status.name}')
      ..writeln('Media kind: ${mediaKind.name}')
      ..writeln('Source: $sourcePath')
      ..writeln('Destination: ${destinationPath.isEmpty ? '(none)' : destinationPath}');

    if (ffmpegPath != null && ffmpegPath.trim().isNotEmpty) {
      buffer.writeln('FFmpeg: $ffmpegPath');
    }
    if (arguments != null && arguments.isNotEmpty) {
      buffer.writeln('Command: ${_formatCommand(ffmpegPath, arguments)}');
    }
    if (exitCode != null) {
      buffer.writeln('Exit code: $exitCode');
    }
    if (errorMessage != null && errorMessage.trim().isNotEmpty) {
      buffer.writeln('Error: $errorMessage');
    }
    if (note != null && note.trim().isNotEmpty) {
      buffer.writeln('Note: $note');
    }

    buffer
      ..writeln()
      ..writeln('--- STDOUT ---')
      ..writeln((stdoutOutput == null || stdoutOutput.isEmpty) ? '(empty)' : stdoutOutput.trimRight())
      ..writeln()
      ..writeln('--- STDERR ---')
      ..writeln((stderrOutput == null || stderrOutput.isEmpty) ? '(empty)' : stderrOutput.trimRight());

    return buffer.toString();
  }

  String _formatCommand(String? ffmpegPath, List<String> arguments) {
    final parts = <String>[
      if (ffmpegPath != null && ffmpegPath.trim().isNotEmpty) ffmpegPath,
      ...arguments,
    ];
    return parts.map(_quoteIfNeeded).join(' ');
  }

  String _quoteIfNeeded(String value) {
    if (value.contains(RegExp(r'\s'))) {
      return '"${value.replaceAll('"', r'\"')}"';
    }
    return value;
  }

  String _timestampSlug(DateTime value) {
    return value
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
  }

  String _safeName(String value) {
    final normalized = value.trim().toLowerCase();
    final safe = normalized.replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');
    return safe.isEmpty ? 'conversion' : safe;
  }
}
