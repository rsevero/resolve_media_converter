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
    int? bitDepth,
    int sourceRotationDegrees = 0,
  }) {
    final arguments = <String>[
      '-hide_banner',
      '-y',
      // We compute the rotation to apply ourselves (source metadata combined
      // with the user's request), so disable ffmpeg's own implicit
      // auto-rotation to avoid applying the source's correction twice.
      '-noautorotate',
    ];

    if (request.startTime != null) {
      // Input-side -ss: modern ffmpeg seeks accurately (not just to the
      // nearest keyframe) when -ss precedes -i for demuxers that support it,
      // so a single -ss here is both fast and frame-accurate. Do not also
      // add -ss after -i — that would apply the start offset a second time.
      arguments.addAll(['-ss', _formatDuration(request.startTime!)]);
    }

    arguments.addAll(['-i', sourcePath]);

    if (request.endTime != null) {
      // Because -ss is applied as an input option, ffmpeg resets the output
      // timeline to zero at the seek point, so -to (an absolute output
      // timestamp) would actually land at endTime after the seek instead of
      // at endTime measured from the start of the source. Use -t (duration)
      // relative to startTime instead so the trim always ends at endTime.
      final duration = request.startTime != null
          ? request.endTime! - request.startTime!
          : request.endTime!;
      arguments.addAll(['-t', _formatDuration(duration)]);
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
      final is10bit = bitDepth != null && bitDepth > 8;
      final netRotationDegrees = request.rotation == VideoRotation.removeMetadata
          ? 0
          : (sourceRotationDegrees + _rotationDegrees(request.rotation)) % 360;
      final rotationFilter = _rotationFilter(netRotationDegrees);
      if (rotationFilter != null) {
        arguments.addAll(['-vf', rotationFilter]);
      }
      arguments.addAll([
        '-c:v',
        'dnxhd',
        '-profile:v',
        is10bit ? 'dnxhr_hqx' : 'dnxhr_hq',
        '-pix_fmt',
        is10bit ? 'yuv422p10le' : 'yuv422p',
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

  int _rotationDegrees(VideoRotation rotation) {
    return switch (rotation) {
      VideoRotation.none => 0,
      VideoRotation.clockwise90 => 90,
      VideoRotation.rotate180 => 180,
      VideoRotation.counterClockwise90 => 270,
      VideoRotation.removeMetadata => 0,
    };
  }

  String? _rotationFilter(int netRotationDegrees) {
    return switch (netRotationDegrees) {
      90 => 'transpose=1',
      180 => 'transpose=1,transpose=1',
      270 => 'transpose=2',
      _ => null,
    };
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$milliseconds';
  }
}
