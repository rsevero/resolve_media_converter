import 'conversion_enums.dart';

class ConversionResult {
  const ConversionResult({
    required this.sourcePath,
    required this.destinationPath,
    required this.status,
    required this.mediaKind,
    this.errorMessage,
    this.elapsed,
    this.logFilePath,
  });

  final String sourcePath;
  final String destinationPath;
  final ConversionStatus status;
  final MediaKind mediaKind;
  final String? errorMessage;
  final Duration? elapsed;
  final String? logFilePath;
}
