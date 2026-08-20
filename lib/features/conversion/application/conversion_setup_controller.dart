import 'package:flutter/foundation.dart';

import '../../../models/conversion_enums.dart';
import '../../../models/conversion_request.dart';
import '../../../services/trim_parser_service.dart';

class ConversionSetupController extends ChangeNotifier {
  ConversionSetupController({TrimParserService? trimParserService})
      : _trimParserService = trimParserService ?? const TrimParserService();

  final TrimParserService _trimParserService;

  SourceType _sourceType = SourceType.file;
  OutputMode _outputMode = OutputMode.sameFolderSuffix;
  VideoRotation _rotation = VideoRotation.none;
  String? _selectedSourcePath;
  String _startTimeText = '';
  String _endTimeText = '';
  String _durationText = '';
  String? _startTimeError;
  String? _endTimeError;
  String? _durationError;

  SourceType get sourceType => _sourceType;
  OutputMode get outputMode => _outputMode;
  VideoRotation get rotation => _rotation;
  String? get selectedSourcePath => _selectedSourcePath;
  String get startTimeText => _startTimeText;
  String get endTimeText => _endTimeText;
  String get durationText => _durationText;
  String? get startTimeError => _startTimeError;
  String? get endTimeError => _endTimeError;
  String? get durationError => _durationError;

  bool get hasSourceSelection =>
      _selectedSourcePath != null && _selectedSourcePath!.trim().isNotEmpty;

  bool get hasValidTrimRange =>
      _startTimeError == null && _endTimeError == null && _durationError == null;

  void setSourceType(SourceType value) {
    if (_sourceType == value) {
      return;
    }

    _sourceType = value;
    _selectedSourcePath = null;
    notifyListeners();
  }

  void setOutputMode(OutputMode value) {
    if (_outputMode == value) {
      return;
    }

    _outputMode = value;
    notifyListeners();
  }

  void setRotation(VideoRotation value) {
    if (_rotation == value) {
      return;
    }

    _rotation = value;
    notifyListeners();
  }

  void setSelectedSourcePath(String? value) {
    final normalized = value?.trim();
    _selectedSourcePath = normalized == null || normalized.isEmpty ? null : normalized;
    notifyListeners();
  }

  void resetTrimValues() {
    _startTimeText = '';
    _endTimeText = '';
    _durationText = '';
    _startTimeError = null;
    _endTimeError = null;
    _durationError = null;
    _rotation = VideoRotation.none;
    notifyListeners();
  }

  void updateStartTimeText(String value) {
    _startTimeText = value;
    _validateTrimRange();
    notifyListeners();
  }

  void updateEndTimeText(String value) {
    _endTimeText = value;
    _validateTrimRange();
    notifyListeners();
  }

  void updateDurationText(String value) {
    _durationText = value;
    _validateTrimRange();
    notifyListeners();
  }

  bool validateBeforeConversion() {
    _validateTrimRange();
    notifyListeners();
    return hasValidTrimRange && hasSourceSelection;
  }

  ConversionRequest? buildRequest({
    required String ffmpegPath,
    required String ffprobePath,
  }) {
    if (!validateBeforeConversion() || !hasSourceSelection) {
      return null;
    }

    final startResult = _trimParserService.parse(_startTimeText);
    final endResult = _trimParserService.parse(_endTimeText);
    final durationResult = _trimParserService.parse(_durationText);

    var effectiveEndTime = endResult.duration;
    if (effectiveEndTime == null && durationResult.duration != null) {
      effectiveEndTime =
          (startResult.duration ?? Duration.zero) + durationResult.duration!;
    }

    return ConversionRequest(
      sourcePath: _selectedSourcePath!,
      sourceType: _sourceType,
      outputMode: _outputMode,
      ffmpegPath: ffmpegPath,
      ffprobePath: ffprobePath,
      startTime: startResult.duration,
      endTime: effectiveEndTime,
      rotation: _rotation,
    );
  }

  void _validateTrimRange() {
    final startResult = _trimParserService.parse(_startTimeText);
    final endResult = _trimParserService.parse(_endTimeText);
    final durationResult = _trimParserService.parse(_durationText);

    _startTimeError = startResult.errorMessage;
    _endTimeError = endResult.errorMessage;
    _durationError = durationResult.errorMessage;

    final hasEndTime = endResult.duration != null;
    final hasDuration = durationResult.duration != null;

    if (hasEndTime && hasDuration) {
      const message = 'Set either an end time or a duration, not both.';
      _endTimeError ??= message;
      _durationError ??= message;
      return;
    }

    if (_startTimeError != null || _endTimeError != null || _durationError != null) {
      return;
    }

    if (startResult.duration != null &&
        hasEndTime &&
        endResult.duration! <= startResult.duration!) {
      _endTimeError = 'End time must be greater than start time.';
    }

    if (hasDuration && durationResult.duration! <= Duration.zero) {
      _durationError = 'Duration must be greater than zero.';
    }
  }
}
