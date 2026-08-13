import 'conversion_enums.dart';

class ConversionRequest {
  const ConversionRequest({
    required this.sourcePath,
    required this.sourceType,
    required this.outputMode,
    required this.ffmpegPath,
    required this.ffprobePath,
    this.startTime,
    this.endTime,
    this.rotation = VideoRotation.none,
  });

  final String sourcePath;
  final SourceType sourceType;
  final OutputMode outputMode;
  final Duration? startTime;
  final Duration? endTime;
  final VideoRotation rotation;
  final String ffmpegPath;
  final String ffprobePath;
}
