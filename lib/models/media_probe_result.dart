import 'conversion_enums.dart';

class MediaProbeResult {
  const MediaProbeResult({
    required this.sourcePath,
    required this.mediaKind,
    this.details,
    this.errorMessage,
    this.isAcceptedForResolve = false,
    this.acceptedFormatLabel,
  });

  final String sourcePath;
  final MediaKind mediaKind;
  final Map<String, Object?>? details;
  final String? errorMessage;
  final bool isAcceptedForResolve;
  final String? acceptedFormatLabel;
}
