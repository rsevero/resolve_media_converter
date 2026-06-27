import 'package:flutter/foundation.dart';

import '../../../models/conversion_enums.dart';
import '../../../models/conversion_request.dart';
import '../../../models/conversion_result.dart';
import '../../../services/conversion_execution_service.dart';
import '../../../services/conversion_log_service.dart';
import '../../../services/ffmpeg_command_service.dart';
import '../../../services/media_probe_service.dart';
import '../../../services/output_path_service.dart';
import '../../../services/source_resolution_service.dart';

class ConversionRunController extends ChangeNotifier {
  ConversionRunController({
    SourceResolutionService? sourceResolutionService,
    MediaProbeService? mediaProbeService,
    OutputPathService? outputPathService,
    FfmpegCommandService? ffmpegCommandService,
    ConversionExecutionService? conversionExecutionService,
    ConversionLogService? conversionLogService,
  })  : _sourceResolutionService =
            sourceResolutionService ?? const SourceResolutionService(),
        _mediaProbeService = mediaProbeService ?? const MediaProbeService(),
        _outputPathService = outputPathService ?? const OutputPathService(),
        _ffmpegCommandService = ffmpegCommandService ?? const FfmpegCommandService(),
        _conversionExecutionService =
            conversionExecutionService ?? const ConversionExecutionService(),
        _conversionLogService = conversionLogService ?? const ConversionLogService();

  final SourceResolutionService _sourceResolutionService;
  final MediaProbeService _mediaProbeService;
  final OutputPathService _outputPathService;
  final FfmpegCommandService _ffmpegCommandService;
  final ConversionExecutionService _conversionExecutionService;
  final ConversionLogService _conversionLogService;

  bool _isRunning = false;
  String? _currentItem;
  String? _errorMessage;
  List<ConversionResult> _results = const [];
  int _completedJobs = 0;
  int _totalJobs = 0;

  bool get isRunning => _isRunning;
  String? get currentItem => _currentItem;
  String? get errorMessage => _errorMessage;
  List<ConversionResult> get results => _results;
  int get completedJobs => _completedJobs;
  int get totalJobs => _totalJobs;

  double get progress =>
      _totalJobs == 0 ? 0 : _completedJobs / _totalJobs;

  void clearResults() {
    _results = const [];
    _errorMessage = null;
    _currentItem = null;
    _completedJobs = 0;
    _totalJobs = 0;
    notifyListeners();
  }

  Future<void> run(ConversionRequest request) async {
    _isRunning = true;
    _errorMessage = null;
    _results = const [];
    _currentItem = null;
    _completedJobs = 0;
    _totalJobs = 0;
    notifyListeners();

    final resolution = await _sourceResolutionService.resolve(
      sourcePath: request.sourcePath,
      sourceType: request.sourceType,
    );

    final results = <ConversionResult>[
      for (final skippedPath in resolution.skippedPaths)
        ConversionResult(
          sourcePath: skippedPath,
          destinationPath: '',
          status: ConversionStatus.skipped,
          mediaKind: MediaKind.unsupported,
          errorMessage: 'Skipped because it is not a regular file.',
          logFilePath: await _conversionLogService.writeLog(
            sourcePath: skippedPath,
            destinationPath: '',
            status: ConversionStatus.skipped,
            mediaKind: MediaKind.unsupported,
            errorMessage: 'Skipped because it is not a regular file.',
            note: 'Top-level directory scanning ignores non-file entries.',
          ),
        ),
    ];

    if (resolution.candidatePaths.isEmpty) {
      _errorMessage = 'No file candidates were found for conversion.';
      _results = results;
      _isRunning = false;
      notifyListeners();
      return;
    }

    _totalJobs = resolution.candidatePaths.length;
    notifyListeners();

    for (final sourcePath in resolution.candidatePaths) {
      _currentItem = sourcePath;
      notifyListeners();

      final probeResult = await _mediaProbeService.probe(
        ffprobePath: request.ffprobePath,
        sourcePath: sourcePath,
      );

      if (probeResult.mediaKind == MediaKind.unsupported) {
        results.add(
          ConversionResult(
            sourcePath: sourcePath,
            destinationPath: '',
            status: ConversionStatus.skipped,
            mediaKind: MediaKind.unsupported,
            errorMessage: probeResult.errorMessage ?? 'Unsupported file.',
            logFilePath: await _conversionLogService.writeLog(
              sourcePath: sourcePath,
              destinationPath: '',
              status: ConversionStatus.skipped,
              mediaKind: MediaKind.unsupported,
              errorMessage: probeResult.errorMessage ?? 'Unsupported file.',
              note: 'ffprobe did not report a supported audio or video stream.',
            ),
          ),
        );
        _completedJobs++;
        notifyListeners();
        continue;
      }

      if (probeResult.isAcceptedForResolve) {
        final acceptedFormatLabel =
            probeResult.acceptedFormatLabel ?? 'already accepted by Resolve';
        results.add(
          ConversionResult(
            sourcePath: sourcePath,
            destinationPath: sourcePath,
            status: ConversionStatus.skipped,
            mediaKind: probeResult.mediaKind,
            errorMessage: 'Skipped because it is already in an accepted format: $acceptedFormatLabel.',
            logFilePath: await _conversionLogService.writeLog(
              sourcePath: sourcePath,
              destinationPath: sourcePath,
              status: ConversionStatus.skipped,
              mediaKind: probeResult.mediaKind,
              errorMessage:
                  'Skipped because it is already in an accepted format: $acceptedFormatLabel.',
              note: 'No conversion was run because the source is already Resolve-friendly.',
            ),
          ),
        );
        _completedJobs++;
        notifyListeners();
        continue;
      }

      final destinationPath = await _outputPathService.buildDestinationPath(
        sourcePath: sourcePath,
        mediaKind: probeResult.mediaKind,
        outputMode: request.outputMode,
      );

      final job = _ffmpegCommandService.buildJob(
        request: request,
        sourcePath: sourcePath,
        destinationPath: destinationPath,
        mediaKind: probeResult.mediaKind,
      );

      final result = await _conversionExecutionService.execute(
        ffmpegPath: request.ffmpegPath,
        job: job,
      );

      results.add(result);
      _completedJobs++;
      notifyListeners();
    }

    _results = results;
    _currentItem = null;
    _isRunning = false;
    notifyListeners();
  }
}
