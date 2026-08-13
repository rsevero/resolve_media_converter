import 'conversion_enums.dart';

class MediaProbeResult {
  const MediaProbeResult({
    required this.sourcePath,
    required this.mediaKind,
    this.details,
    this.errorMessage,
    this.isAcceptedForResolve = false,
    this.acceptedFormatLabel,
    this.bitDepth,
    this.durationSeconds,
    this.sourceRotationDegrees = 0,
  });

  final String sourcePath;
  final MediaKind mediaKind;
  final Map<String, Object?>? details;
  final String? errorMessage;
  final bool isAcceptedForResolve;
  final String? acceptedFormatLabel;
  final int? bitDepth;
  final double? durationSeconds;

  /// Clockwise degrees (0/90/180/270) needed to display the source's stored
  /// pixels upright, derived from its rotation metadata (display matrix or
  /// legacy `rotate` tag). 0 when the source has no rotation metadata.
  final int sourceRotationDegrees;
}
