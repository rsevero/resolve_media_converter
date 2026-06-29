import '../models/conversion_enums.dart';
import '../models/conversion_request.dart';
import '../models/resolved_job.dart';

class FfmpegCommandService {
  const FfmpegCommandService();

  ResolvedJob buildJob({
    required ConversionRequest request,
    required String sourcePath,
    required String destinationPath,
    required MediaKind mediaKind,
  }) {
    final arguments = <String>[
      '-hide_banner',
      '-y',
    ];

    if (request.startTime != null) {
      arguments.addAll(['-ss', _formatDuration(request.startTime!)]);
    }

    arguments.addAll(['-i', sourcePath]);

    if (request.startTime != null) {
      arguments.addAll(['-ss', _formatDuration(request.startTime!)]);
    }

    if (request.endTime != null) {
      arguments.addAll(['-to', _formatDuration(request.endTime!)]);
    }

    if (mediaKind == MediaKind.audio) {
      arguments.addAll([
        '-vn',
        '-c:a',
        'pcm_s24le',
        '-ar',
        '48000',
        destinationPath,
      ]);
    } else {
      arguments.addAll([
        '-c:v',
        'dnxhd',
        '-profile:v',
        'dnxhr_hq',
        '-c:a',
        'pcm_s24le',
        '-ar',
        '48000',
        destinationPath,
      ]);
    }

    return ResolvedJob(
      sourcePath: sourcePath,
      destinationPath: destinationPath,
      mediaKind: mediaKind,
      arguments: arguments,
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$milliseconds';
  }
}
