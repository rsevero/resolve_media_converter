import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/conversion_enums.dart';
import '../models/media_probe_result.dart';

class MediaProbeService {
  const MediaProbeService();

  Future<MediaProbeResult> probe({
    required String ffprobePath,
    required String sourcePath,
  }) async {
    try {
      final result = await Process.run(ffprobePath, [
        '-v',
        'error',
        '-show_entries',
        'format=format_name,format_long_name:stream=codec_type,codec_name,profile,width,height,channels,sample_rate,bits_per_sample,bits_per_raw_sample,sample_fmt,avg_frame_rate,r_frame_rate',
        '-of',
        'json',
        sourcePath,
      ], runInShell: Platform.isWindows);

      if (result.exitCode != 0) {
        return MediaProbeResult(
          sourcePath: sourcePath,
          mediaKind: MediaKind.unsupported,
          errorMessage: _firstLine(result.stderr) ?? 'ffprobe failed.',
        );
      }

      return parseProbeOutput(sourcePath: sourcePath, jsonOutput: result.stdout.toString());
    } on ProcessException catch (error) {
      return MediaProbeResult(
        sourcePath: sourcePath,
        mediaKind: MediaKind.unsupported,
        errorMessage: error.message,
      );
    } on FormatException catch (error) {
      return MediaProbeResult(
        sourcePath: sourcePath,
        mediaKind: MediaKind.unsupported,
        errorMessage: error.message,
      );
    }
  }

  MediaProbeResult parseProbeOutput({
    required String sourcePath,
    required String jsonOutput,
  }) {
    final decoded = jsonDecode(jsonOutput) as Map<String, dynamic>;
    final streams = (decoded['streams'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final format = (decoded['format'] as Map<String, dynamic>? ?? const {});

    final hasVideo = streams.any((stream) => stream['codec_type'] == 'video');
    final hasAudio = streams.any((stream) => stream['codec_type'] == 'audio');
    final acceptedFormatLabel = _detectAcceptedFormat(
      sourcePath: sourcePath,
      format: format,
      streams: streams,
    );

    final mediaKind = hasVideo
        ? MediaKind.video
        : hasAudio
            ? MediaKind.audio
            : MediaKind.unsupported;

    return MediaProbeResult(
      sourcePath: sourcePath,
      mediaKind: mediaKind,
      details: {
        'streamCount': streams.length,
        'hasAudio': hasAudio,
        'hasVideo': hasVideo,
        'formatName': format['format_name'],
        'acceptedFormatLabel': acceptedFormatLabel,
      },
      errorMessage:
          mediaKind == MediaKind.unsupported ? 'No audio or video stream found.' : null,
      isAcceptedForResolve: acceptedFormatLabel != null,
      acceptedFormatLabel: acceptedFormatLabel,
    );
  }

  String? _detectAcceptedFormat({
    required String sourcePath,
    required Map<String, dynamic> format,
    required List<Map<String, dynamic>> streams,
  }) {
    final extension = path.extension(sourcePath).toLowerCase();
    final formatNames = (format['format_name']?.toString() ?? '')
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final videoStream = streams.cast<Map<String, dynamic>?>().firstWhere(
          (stream) => stream?['codec_type'] == 'video',
          orElse: () => null,
        );
    final audioStream = streams.cast<Map<String, dynamic>?>().firstWhere(
          (stream) => stream?['codec_type'] == 'audio',
          orElse: () => null,
        );

    if (_isAcceptedBrawOrCinemaDng(extension: extension, videoStream: videoStream)) {
      return extension == '.braw' ? 'BRAW' : 'CinemaDNG';
    }

    if (videoStream != null &&
        _isAcceptedH264Mp4(
          extension: extension,
          formatNames: formatNames,
          videoStream: videoStream,
        )) {
      return 'H.264 MP4 (constant frame rate)';
    }

    if (videoStream != null &&
        _isAcceptedProResMov(
          extension: extension,
          formatNames: formatNames,
          videoStream: videoStream,
        )) {
      return 'Apple ProRes';
    }

    if (videoStream != null &&
        _isAcceptedDnxhr(
          extension: extension,
          formatNames: formatNames,
          videoStream: videoStream,
        )) {
      return 'Avid DNxHR';
    }

    if (audioStream != null &&
        !streams.any((stream) => stream['codec_type'] == 'video') &&
        _isAcceptedWav(
          extension: extension,
          formatNames: formatNames,
          audioStream: audioStream,
        )) {
      return '48 kHz / 24-bit WAV/BWF';
    }

    return null;
  }

  bool _isAcceptedBrawOrCinemaDng({
    required String extension,
    required Map<String, dynamic>? videoStream,
  }) {
    if (extension == '.braw') {
      return true;
    }

    final codecName = videoStream?['codec_name']?.toString().toLowerCase() ?? '';
    return extension == '.dng' || codecName.contains('cdng');
  }

  bool _isAcceptedH264Mp4({
    required String extension,
    required Set<String> formatNames,
    required Map<String, dynamic> videoStream,
  }) {
    final codecName = videoStream['codec_name']?.toString().toLowerCase();
    if (codecName != 'h264') {
      return false;
    }

    final isMp4 = extension == '.mp4' ||
        formatNames.contains('mp4') ||
        formatNames.contains('mov,mp4,m4a,3gp,3g2,mj2');
    if (!isMp4) {
      return false;
    }

    final averageRate = _parseFrameRate(videoStream['avg_frame_rate']?.toString());
    final realRate = _parseFrameRate(videoStream['r_frame_rate']?.toString());
    return averageRate != null &&
        realRate != null &&
        averageRate > 0 &&
        realRate > 0 &&
        (averageRate - realRate).abs() < 0.0001;
  }

  bool _isAcceptedProResMov({
    required String extension,
    required Set<String> formatNames,
    required Map<String, dynamic> videoStream,
  }) {
    final codecName = videoStream['codec_name']?.toString().toLowerCase();
    if (codecName != 'prores') {
      return false;
    }

    final isMov = extension == '.mov' ||
        formatNames.contains('mov') ||
        formatNames.contains('mov,mp4,m4a,3gp,3g2,mj2');
    if (!isMov) {
      return false;
    }

    final profile = videoStream['profile']?.toString().toLowerCase() ?? '';
    return profile.contains('422') || profile.contains('4444');
  }

  bool _isAcceptedDnxhr({
    required String extension,
    required Set<String> formatNames,
    required Map<String, dynamic> videoStream,
  }) {
    final codecName = videoStream['codec_name']?.toString().toLowerCase() ?? '';
    final profile = videoStream['profile']?.toString().toLowerCase() ?? '';
    final isDnx = codecName == 'dnxhd' || codecName == 'dnxhr';
    final isSupportedContainer = extension == '.mov' ||
        extension == '.mxf' ||
        formatNames.contains('mxf') ||
        formatNames.contains('mov') ||
        formatNames.contains('mov,mp4,m4a,3gp,3g2,mj2');
    return isDnx && isSupportedContainer && profile.contains('dnxhr');
  }

  bool _isAcceptedWav({
    required String extension,
    required Set<String> formatNames,
    required Map<String, dynamic> audioStream,
  }) {
    final codecName = audioStream['codec_name']?.toString().toLowerCase() ?? '';
    final sampleRate = int.tryParse(audioStream['sample_rate']?.toString() ?? '');
    final bitsPerSample = int.tryParse(audioStream['bits_per_sample']?.toString() ?? '');
    final bitsPerRawSample = int.tryParse(
      audioStream['bits_per_raw_sample']?.toString() ?? '',
    );
    final isWavContainer = extension == '.wav' ||
        extension == '.bwf' ||
        formatNames.contains('wav') ||
        formatNames.contains('w64');

    final is24BitPcm = codecName == 'pcm_s24le' ||
        codecName == 'pcm_s24be' ||
        bitsPerSample == 24 ||
        bitsPerRawSample == 24;

    return isWavContainer && sampleRate == 48000 && is24BitPcm;
  }

  double? _parseFrameRate(String? value) {
    if (value == null || value.isEmpty || value == '0/0') {
      return null;
    }

    final parts = value.split('/');
    if (parts.length == 2) {
      final numerator = double.tryParse(parts[0]);
      final denominator = double.tryParse(parts[1]);
      if (numerator == null || denominator == null || denominator == 0) {
        return null;
      }
      return numerator / denominator;
    }

    return double.tryParse(value);
  }

  String? _firstLine(Object? value) {
    return value
        .toString()
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere(
          (line) => line.isNotEmpty,
          orElse: () => '',
        )
        .ifEmptyToNull();
  }
}

extension on String {
  String? ifEmptyToNull() => isEmpty ? null : this;
}
